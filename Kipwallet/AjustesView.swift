import SwiftUI
import PhotosUI
import UserNotifications

// La pantalla Ajustes (AjustesScreen.kt de la Android): la lista de 14
// piezas en su orden exacto — perfil, membresia (solo lectura: el
// cobro es solo web), banco, datos, avisos locales, tema, las entradas
// a las subsecciones y los interruptores de correo y push. Las
// subsecciones viven en AjustesSecciones.swift.

let PALETA_COLORES_CATEGORIA: [String] = [
    "#5EC96E", "#4C9BE8", "#F2A65A", "#9B7EDE", "#F2789F", "#38B2AC",
    "#ECC94B", "#E53E3E", "#667EEA", "#8D6E63", "#9FB0BF", "#2FA36B",
]

let FRECUENCIAS_CICLO: [(String, String)] = [
    ("semanal", "Cada semana"), ("quincenal", "Cada dos semanas"),
    ("dos_veces_mes", "Dos veces al mes"), ("mensual", "Cada mes"),
]

func etiquetaFrecuencia(_ clave: String) -> String {
    FRECUENCIAS_CICLO.first { $0.0 == clave }?.1 ?? clave
}

/// Los avisos locales de cobros (la preferencia de este telefono): se
/// programan con los proximos cobros del servidor, dos dias antes y el
/// mismo dia, como el worker de la Android.
enum AvisosCobrosLocales {
    static func estadoPermiso() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func pedirPermiso() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func cancelar() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func programar() async {
        cancelar()
        guard let datos = try? await Api.recurrentes(orden: "fecha") else { return }
        let centro = UNUserNotificationCenter.current()
        let cal = Calendar.current
        for cargo in datos.cargos where !cargo.cancelada {
            guard let fechaIso = cargo.proximaFecha, let fecha = parseFecha(fechaIso) else { continue }
            for (desplazamiento, sufijo) in [(-2, "menos2"), (0, "mismo")] {
                guard let base = cal.date(byAdding: .day, value: desplazamiento, to: fecha) else { continue }
                var componentes = cal.dateComponents([.year, .month, .day], from: base)
                componentes.hour = 9
                componentes.minute = 0
                guard let disparo = cal.date(from: componentes), disparo > Date() else { continue }
                let contenido = UNMutableNotificationContent()
                contenido.title = desplazamiento == 0 ? "Hoy tienes un cobro" : "Cobro que viene"
                contenido.body = "\(cargo.comercio) · \(cargo.montoTexto)"
                contenido.sound = .default
                let disparador = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
                let pedido = UNNotificationRequest(
                    identifier: "kw-aviso-\(cargo.comercio)-\(sufijo)",
                    content: contenido,
                    trigger: disparador)
                centro.add(pedido, withCompletionHandler: nil)
            }
        }
    }
}

@MainActor
final class AjustesModelo: ObservableObject {
    @Published var ajustes: AjustesRespuesta? = nil
    @Published var cuentas: [CuentaEstado] = []
    @Published var membresiaGestion: MembresiaGestion? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var procesando = false
    @Published var dialogoExito: String? = nil
    @Published var dialogoError: String? = nil
    @Published var cargadoUnaVez = false

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            ajustes = try await Api.ajustes()
            cargando = false
            cargadoUnaVez = true
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
            return
        } catch {
            errorTexto = "No se pudieron cargar tus ajustes."
            cargando = false
            return
        }
        await recargarExtras()
    }

    /// Las cargas de apoyo (cuentas y membresia): si fallan se ignoran.
    func recargarExtras() async {
        async let cuentasNuevas = try? await Api.cuentasEstado().cuentas
        async let membresiaNueva = try? await Api.membresia()
        if let c = await cuentasNuevas { cuentas = c }
        if let m = await membresiaNueva { membresiaGestion = m }
    }

    /// Recarga silenciosa tras una accion (sin spinner), como la Android.
    func recargar() async {
        if let nuevos = try? await Api.ajustes() { ajustes = nuevos }
        await recargarExtras()
    }

    /// El patron de los dialogos globales: «Listo» con el mensaje del
    /// servidor o «Algo salió mal» con el error, y recarga al terminar.
    func ejecutar(alExito: (() -> Void)? = nil, _ trabajo: @escaping () async throws -> String?) {
        if procesando { return }
        procesando = true
        Task {
            do {
                let mensaje = try await trabajo()
                procesando = false
                dialogoExito = mensaje ?? "Listo."
                await recargar()
                alExito?()
            } catch let e as ApiError {
                procesando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                dialogoError = e.errorDescription
            } catch {
                procesando = false
                dialogoError = "No se pudo completar la acción. Intenta de nuevo."
            }
        }
    }
}

struct AjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo = AjustesModelo()
    @State private var seccion: String? = nil
    @State private var nombre = ""
    @State private var correo = ""
    @State private var confirmarCorreo = false
    @State private var fotoItem: PhotosPickerItem? = nil
    @State private var gruposExpandidos: Set<String> = []
    @State private var notaPlaid = false
    @State private var prefs: NotificacionesPrefs? = nil
    @State private var cerrando = false
    @AppStorage("kw_avisos_cobros") private var avisosCobros = false
    @State private var permisoAvisosFalta = false
    @State private var permisoAvisosDenegado = false
    @AppStorage("kw_modo_tema") private var modoTema = "sistema"

    var body: some View {
        Group {
            switch seccion {
            case "ciclo":
                CicloPagoAjustesView(modelo: modelo, alVolver: { seccion = nil })
            case "categorias":
                CategoriasAjustesView(modelo: modelo, alVolver: { seccion = nil })
            case "reglas":
                ReglasAjustesView(modelo: modelo, alVolver: { seccion = nil })
            case "seguridad":
                SeguridadAjustesView(modelo: modelo, alVolver: { seccion = nil })
            case "asistente":
                AsistenteAjustesView(modelo: modelo, alVolver: { seccion = nil })
            case "contrasena":
                ContrasenaAjustesView(modelo: modelo, alVolver: { seccion = nil })
            default:
                lista
            }
        }
        .alert("Listo", isPresented: Binding(get: { modelo.dialogoExito != nil }, set: { if !$0 { modelo.dialogoExito = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(modelo.dialogoExito ?? "Listo.")
        }
        .alert("Algo salió mal", isPresented: Binding(get: { modelo.dialogoError != nil }, set: { if !$0 { modelo.dialogoError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(modelo.dialogoError ?? "")
        }
        .alert("Conectar un banco", isPresented: $notaPlaid) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Conectar y reconectar bancos llega en la siguiente ronda, con Plaid dentro de la app.")
        }
    }

    private var lista: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { cerrar() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text("Ajustes")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.ajustes != nil) {
                if let ajustes = modelo.ajustes {
                    ScrollView {
                        VStack(spacing: 0) {
                            tarjetaPerfil(ajustes)
                            if let membresia = modelo.membresiaGestion {
                                tarjetaMembresia(membresia)
                            }
                            tarjetaBanco
                            tarjetaDatos
                            tarjetaAvisosLocales
                            tarjetaTema
                            EntradaAjustes(titulo: "Ciclo de pago",
                                           subtitulo: (ajustes.ciclo?.configurado ?? false) ? "Cómo y cuándo te pagan" : "Todavía no lo configuras") { seccion = "ciclo" }
                            EntradaAjustes(titulo: "Reglas de movimientos",
                                           subtitulo: "\(ajustes.reglas.filter { $0.activa }.count) reglas activas") { seccion = "reglas" }
                            EntradaAjustes(titulo: "Categorías",
                                           subtitulo: "Los colores de cada categoría y tus categorías propias") { seccion = "categorias" }
                            EntradaAjustes(titulo: "Verificación en dos pasos",
                                           subtitulo: (ajustes.seguridad?.activa ?? false) ? "Activa: un código extra al entrar" : "Apagada: actívala para cuidar tu cuenta") { seccion = "seguridad" }
                            EntradaAjustes(titulo: "Conecta tu asistente",
                                           subtitulo: "Una llave para que tu asistente consulte tus datos") { seccion = "asistente" }
                            if prefs != nil {
                                tarjetaCorreo
                                tarjetaPush
                            }
                            Button {
                                cerrarSesion()
                            } label: {
                                Text(cerrando ? "Cerrando…" : "Cerrar sesión")
                                    .font(.manrope(16, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(cerrando)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            Color.clear.frame(height: 110)
                        }
                    }
                    .refreshable { await modelo.recargar() }
                }
            } reintentar: {
                Task { await modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme))
        .task {
            if modelo.ajustes == nil { await modelo.cargar() }
            await revisarPermisoAvisos()
        }
        .onChange(of: modelo.cargadoUnaVez) { listo in
            if listo, let ajustes = modelo.ajustes {
                nombre = ajustes.perfil?.nombre ?? ""
                correo = ajustes.perfil?.correo ?? ""
                if prefs == nil { prefs = ajustes.notificaciones }
            }
        }
        .onChange(of: fotoItem) { item in
            guard let item = item else { return }
            Task {
                if let datos = try? await item.loadTransferable(type: Data.self) {
                    modelo.ejecutar {
                        _ = try await Api.subirFoto(datos: datos)
                        return "Tu foto se actualizó."
                    }
                }
            }
        }
        .alert("Cambiar tu correo", isPresented: $confirmarCorreo) {
            Button("Cancelar", role: .cancel) {}
            Button("Enviar la confirmación") {
                let nuevo = correo.trimmingCharacters(in: .whitespaces)
                modelo.ejecutar {
                    try await Api.cambiarCorreo(correo: nuevo).mensaje
                }
            }
        } message: {
            Text("Te enviaremos un correo de confirmación a \(correo.trimmingCharacters(in: .whitespaces)). El cambio se completa cuando tocas el enlace que te llegue.")
        }
    }

    // MARK: - Perfil

    private func tarjetaPerfil(_ ajustes: AjustesRespuesta) -> some View {
        let perfil = ajustes.perfil
        return KipCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    FotoPerfilAjustes(fotoUrl: perfil?.fotoUrl, nombre: perfil?.nombre ?? "")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(perfil?.nombre ?? "")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(perfil?.correo ?? "")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
                PhotosPicker(selection: $fotoItem, matching: .images) {
                    Text("Cambiar mi foto")
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
                CampoKip(etiqueta: "Tu nombre", texto: $nombre)
                if nombre.trimmingCharacters(in: .whitespaces) != (perfil?.nombre ?? ""),
                   !nombre.trimmingCharacters(in: .whitespaces).isEmpty {
                    BotonPrimario(texto: "Guardar el nombre") {
                        let nuevo = nombre.trimmingCharacters(in: .whitespaces)
                        if nuevo.isEmpty {
                            modelo.dialogoError = "Escribe tu nombre."
                            return
                        }
                        modelo.ejecutar { try await Api.guardarPerfil(nombre: nuevo).mensaje }
                    }
                }
                CampoKip(etiqueta: "Tu correo", texto: $correo, tecladoEmail: true)
                if correo.trimmingCharacters(in: .whitespaces).lowercased() != (perfil?.correo ?? "").lowercased(),
                   correo.contains("@") {
                    BotonPrimario(texto: "Cambiar mi correo") { confirmarCorreo = true }
                }
                Button("Cambiar mi contraseña") { seccion = "contrasena" }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Membresia (solo lectura: el cobro es solo web)

    private func tarjetaMembresia(_ membresia: MembresiaGestion) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 6) {
                RotuloAjustes(texto: "TU MEMBRESÍA")
                Text(membresia.titulo)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(membresia.detalle)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Banco

    private var gruposBanco: [(banco: String, cuentas: [CuentaEstado])] {
        var orden: [String] = []
        var grupos: [String: [CuentaEstado]] = [:]
        for cuenta in modelo.cuentas {
            if grupos[cuenta.banco] == nil { orden.append(cuenta.banco) }
            grupos[cuenta.banco, default: []].append(cuenta)
        }
        return orden.map { (banco: $0, cuentas: grupos[$0] ?? []) }
    }

    private var tarjetaBanco: some View {
        KipCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                RotuloAjustes(texto: "TU BANCO")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                if modelo.cuentas.isEmpty {
                    Text("Todavía no conectas un banco.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                } else {
                    ForEach(gruposBanco, id: \.banco) { grupo in
                        grupoBanco(grupo.banco, cuentas: grupo.cuentas)
                    }
                }
                Button("Conectar un banco") { notaPlaid = true }
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func lineaSalud(_ cuentas: [CuentaEstado]) -> (texto: String, esError: Bool) {
        guard let conexion = cuentas.compactMap({ $0.conexion }).first else {
            return ("\(cuentas.count) cuentas", false)
        }
        if conexion.necesitaAtencion {
            var texto = conexion.estadoTexto ?? "Necesita atención"
            if let sync = conexion.ultimaSyncTexto { texto += " · tus datos llegan hasta \(sync)" }
            return (texto, true)
        }
        if conexion.desactualizada {
            return ("Sin sincronizar \(conexion.ultimaSyncTexto ?? "")", true)
        }
        if let sync = conexion.ultimaSyncTexto {
            return ("Última sincronización \(sync)", false)
        }
        return (conexion.estadoTexto ?? "\(cuentas.count) cuentas", false)
    }

    private func grupoBanco(_ banco: String, cuentas: [CuentaEstado]) -> some View {
        let expandido = gruposExpandidos.contains(banco)
        let salud = lineaSalud(cuentas)
        let conexion = cuentas.compactMap { $0.conexion }.first
        return VStack(spacing: 0) {
            Button {
                if expandido { gruposExpandidos.remove(banco) } else { gruposExpandidos.insert(banco) }
            } label: {
                HStack(spacing: 12) {
                    CirculoComercio(nombre: banco, tamano: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(banco)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(salud.texto)
                            .font(.manrope(13))
                            .foregroundStyle(salud.esError ? Color.red : KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    Image(systemName: expandido ? "chevron.up" : "chevron.down")
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            if expandido {
                ForEach(cuentas) { cuenta in
                    HStack(spacing: 12) {
                        CirculoIcono(simbolo: iconoTipoCuentaEstado(cuenta), color: KipPastel.azul, tamano: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cuenta.nombre)
                                .font(.manrope(16, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text(cuenta.mascara != nil ? "•••\(cuenta.mascara!) | \(etiquetaTipoCuentaEstado(cuenta))" : etiquetaTipoCuentaEstado(cuenta))
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer()
                        Text(cuenta.saldoTexto)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    if cuenta.conexion?.necesitaAtencion == true {
                        botonContornoAjustes("Reconectar") { notaPlaid = true }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                }
                if let conexion = conexion, conexion.desactualizada, !conexion.necesitaAtencion {
                    botonContornoAjustes("Sincronizar ahora") {
                        modelo.ejecutar {
                            let r = try await Api.sincronizarCuenta(id: conexion.id)
                            return r.message ?? r.mensaje
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
            Divider().background(KipColor.border(scheme))
        }
    }

    // MARK: - Datos

    private var tarjetaDatos: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                RotuloAjustes(texto: "TUS DATOS")
                Text("Tu información es tuya: bájala cuando quieras. Se abre tu navegador para descargar.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                BotonPrimario(texto: "Exportar todo (ZIP)") { exportar(tipo: "todo", mes: nil) }
                botonContornoAjustes("Cierre del mes pasado (CSV)") {
                    exportar(tipo: "cierre", mes: mesAnterior())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func mesAnterior() -> String {
        let cal = Calendar(identifier: .gregorian)
        let previo = cal.date(byAdding: .month, value: -1, to: Date())!
        return "\(cal.component(.year, from: previo))-\(String(format: "%02d", cal.component(.month, from: previo)))"
    }

    private func exportar(tipo: String, mes: String?) {
        Task {
            do {
                let r = try await Api.exportarDatos(tipo: tipo, mes: mes)
                if let urlTexto = r.url, let url = URL(string: urlTexto) {
                    await UIApplication.shared.open(url)
                }
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.dialogoError = e.errorDescription
            } catch {
                modelo.dialogoError = "No se pudo preparar la descarga."
            }
        }
    }

    // MARK: - Avisos locales y tema

    private var tarjetaAvisosLocales: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Avisos de cobros en este teléfono")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("Te avisamos dos días antes y el mismo día de cada cobro que se repite.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    KipInterruptor(activo: Binding(get: { avisosCobros }, set: { nuevo in
                        Task { await cambiarAvisos(nuevo) }
                    }))
                }
                if avisosCobros && permisoAvisosFalta {
                    Text("Falta el permiso de notificaciones: sin él no podemos mostrarte los avisos.")
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                    Button("Dar el permiso en Ajustes") { abrirAjustesSistema() }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
                if permisoAvisosDenegado {
                    Text("Los avisos quedaron apagados porque falta el permiso. Puedes darlo cuando quieras en los ajustes de tu teléfono.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Button("Abrir los ajustes del teléfono") { abrirAjustesSistema() }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func cambiarAvisos(_ nuevo: Bool) async {
        if nuevo {
            let estado = await AvisosCobrosLocales.estadoPermiso()
            if estado == .authorized {
                avisosCobros = true
                permisoAvisosDenegado = false
                await AvisosCobrosLocales.programar()
            } else {
                let concedido = await AvisosCobrosLocales.pedirPermiso()
                if concedido {
                    avisosCobros = true
                    permisoAvisosDenegado = false
                    permisoAvisosFalta = false
                    await AvisosCobrosLocales.programar()
                } else {
                    avisosCobros = false
                    permisoAvisosDenegado = true
                }
            }
        } else {
            avisosCobros = false
            AvisosCobrosLocales.cancelar()
        }
    }

    private func revisarPermisoAvisos() async {
        let estado = await AvisosCobrosLocales.estadoPermiso()
        permisoAvisosFalta = avisosCobros && estado != .authorized
        if avisosCobros && estado == .authorized {
            await AvisosCobrosLocales.programar()
        }
    }

    private func abrirAjustesSistema() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var tarjetaTema: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 10) {
                RotuloAjustes(texto: "TEMA")
                ForEach([("sistema", "Como mi teléfono"), ("claro", "Claro"), ("oscuro", "Oscuro")], id: \.0) { opcion in
                    Button {
                        modoTema = opcion.0
                    } label: {
                        HStack {
                            Text(opcion.1)
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            Image(systemName: modoTema == opcion.0 ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(modoTema == opcion.0 ? KipColor.accent : KipColor.textSecondary(scheme))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Interruptores de correo y push

    private var tarjetaCorreo: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                RotuloAjustes(texto: "AVISOS POR CORREO")
                filaInterruptor(titulo: "Aviso de presupuesto", texto: "Cuando una categoría se pasa de su presupuesto.",
                                activo: bindingPrefs(\.avisoPresupuesto))
                filaInterruptor(titulo: "Vencimiento de deudas", texto: "Antes de que venza el pago de una tarjeta.",
                                activo: bindingPrefs(\.avisoVencimientoDeuda))
                filaInterruptor(titulo: "Aviso de sobregiro", texto: "Si una cuenta queda en números rojos.",
                                activo: bindingPrefs(\.avisoSobregiro))
                filaInterruptor(titulo: "Resumen semanal", texto: "Un correo cada semana con cómo va tu dinero.",
                                activo: bindingPrefs(\.resumenSemanal))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var tarjetaPush: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                RotuloAjustes(texto: "NOTIFICACIONES PUSH")
                filaInterruptor(titulo: "Avisos de tu dinero", texto: "Tu plan, la salud de tus cuentas, movimientos grandes y tu reporte del mes, en el teléfono.",
                                activo: bindingPush(\.pushDinero))
                filaInterruptor(titulo: "Recordatorios", texto: "El día antes de que venza el pago de una deuda.",
                                activo: bindingPush(\.pushRecordatorios))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func filaInterruptor(titulo: String, texto: String, activo: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(texto)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            KipInterruptor(activo: activo)
        }
    }

    private func bindingPrefs(_ clave: WritableKeyPath<NotificacionesPrefs, Bool>) -> Binding<Bool> {
        Binding(get: { prefs?[keyPath: clave] ?? false }, set: { nuevo in
            guard var p = prefs else { return }
            p[keyPath: clave] = nuevo
            prefs = p
            guardarPrefs()
        })
    }

    private func bindingPush(_ clave: WritableKeyPath<NotificacionesPrefs, Bool>) -> Binding<Bool> {
        Binding(get: { prefs?[keyPath: clave] ?? false }, set: { nuevo in
            guard var p = prefs else { return }
            if nuevo {
                Task {
                    let estado = await AvisosCobrosLocales.estadoPermiso()
                    var concedido = estado == .authorized
                    if !concedido { concedido = await AvisosCobrosLocales.pedirPermiso() }
                    if concedido {
                        p[keyPath: clave] = true
                        prefs = p
                        guardarPrefs()
                    }
                }
            } else {
                p[keyPath: clave] = false
                prefs = p
                guardarPrefs()
            }
        })
    }

    private func guardarPrefs() {
        guard let p = prefs else { return }
        modelo.ejecutar { try await Api.guardarNotificaciones(p).mensaje }
    }

    private func cerrarSesion() {
        if cerrando { return }
        cerrando = true
        Task {
            await Api.logout()
            Sesion.cerrar()
        }
    }
}

// MARK: - Piezas de la lista

struct RotuloAjustes: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String

    var body: some View {
        Text(texto)
            .font(.manrope(12, weight: .bold))
            .foregroundStyle(KipColor.textSecondary(scheme))
    }
}

struct EntradaAjustes: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let subtitulo: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(titulo)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text(subtitulo)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(16)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct BotonContornoAjustes: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

func botonContornoAjustes(_ texto: String, accion: @escaping () -> Void) -> BotonContornoAjustes {
    BotonContornoAjustes(texto: texto, accion: accion)
}

struct FotoPerfilAjustes: View {
    let fotoUrl: String?
    let nombre: String

    var body: some View {
        ZStack {
            if let urlCadena = fotoUrl, let url = URL(string: urlCadena) {
                AsyncImage(url: url) { fase in
                    if case .success(let imagen) = fase {
                        imagen.resizable().scaledToFill()
                    } else {
                        inicial
                    }
                }
            } else {
                inicial
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var inicial: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(nombre.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "K")
                .font(.manrope(22, weight: .heavy))
                .foregroundStyle(KipColor.onAccent)
        }
    }
}

func etiquetaTipoCuentaEstado(_ cuenta: CuentaEstado) -> String {
    let subtipo = (cuenta.subtipo ?? "").lowercased()
    let tipo = cuenta.tipo.lowercased()
    if subtipo == "checking" { return "Cheques" }
    if subtipo == "savings" || tipo == "savings" { return "Ahorros" }
    if tipo == "credit" || subtipo == "credit card" { return "Crédito" }
    if tipo == "loan" { return "Préstamo" }
    if tipo == "investment" || tipo == "brokerage" { return "Inversión" }
    if subtipo == "checking" { return "Cheques" }
    return "Cuenta"
}

func iconoTipoCuentaEstado(_ cuenta: CuentaEstado) -> String {
    switch etiquetaTipoCuentaEstado(cuenta) {
    case "Ahorros": return "piggybank.fill"
    case "Crédito": return "creditcard.fill"
    case "Préstamo": return "dollarsign.circle.fill"
    case "Inversión": return "chart.line.uptrend.xyaxis"
    default: return "building.columns.fill"
    }
}
