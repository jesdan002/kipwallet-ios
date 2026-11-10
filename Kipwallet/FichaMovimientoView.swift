import SwiftUI

// La ficha de un movimiento (FichaMovimientoScreen.kt de la Android):
// cabecera con el comercio, chip de categoria, nombre visible, los tres
// interruptores, etiquetas, nota, partes si esta dividido y las acciones
// (historial, dividir/reunir). El Guardar queda fijo abajo, siempre
// visible, y manda el estado COMPLETO como hace la Android.

@MainActor
final class FichaModelo: ObservableObject {
    @Published var detalle: MovimientoDetalle? = nil
    @Published var categorias: [CategoriaMov] = []
    @Published var cargando = false
    @Published var guardando = false
    @Published var errorTexto: String? = nil
    @Published var mensajeGuardado: String? = nil

    // Estado editable de la ficha
    @Published var categoriaClave: String? = nil
    @Published var nombreMostrar = ""
    @Published var esInterno = false
    @Published var marcadaRecurrente = false
    @Published var revisada = false
    @Published var etiquetas: [String] = []
    @Published var nota = ""

    let id: Int

    init(id: Int) { self.id = id }

    var categoriaElegida: CategoriaMov? {
        categorias.first { $0.clave == categoriaClave } ?? detalle?.categoria
    }

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            let r = try await Api.fichaMovimiento(id: id)
            aplicar(r.movimiento)
            categorias = r.categorias
            cargando = false
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
        } catch {
            errorTexto = "Algo salió mal. Intenta de nuevo."
            cargando = false
        }
    }

    private func aplicar(_ d: MovimientoDetalle) {
        detalle = d
        categoriaClave = d.categoriaCorregida ?? d.categoria?.clave
        nombreMostrar = d.nombreMostrar ?? ""
        esInterno = d.esInterno
        marcadaRecurrente = d.marcadaRecurrente
        revisada = d.revisada
        etiquetas = d.etiquetas
        nota = d.nota ?? ""
        mensajeGuardado = nil
    }

    func tocado() {
        mensajeGuardado = nil
    }

    func guardar() async {
        guardando = true
        errorTexto = nil
        // Siempre el estado completo: el servidor trata "no viaja" como
        // false en is_internal (regla anotada en el mapa).
        let cuerpo: [String: Any] = [
            "category_override": categoriaClave ?? NSNull(),
            "is_internal": esInterno,
            "user_note": nota.trimmingCharacters(in: .whitespaces),
            "nombre_mostrar": nombreMostrar.trimmingCharacters(in: .whitespaces),
            "revisada": revisada,
            "marcada_recurrente": marcadaRecurrente,
            "etiquetas": etiquetas,
        ]
        do {
            let r = try await Api.guardarMovimiento(id: id, cuerpo: cuerpo)
            if let mov = r.movimiento { aplicar(mov) }
            mensajeGuardado = r.mensaje ?? "Cambios guardados."
            guardando = false
        } catch let e as ApiError {
            guardando = false
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription ?? "No se pudieron guardar los cambios."
        } catch {
            guardando = false
            errorTexto = "No se pudieron guardar los cambios."
        }
    }

    func agregarEtiqueta(_ texto: String) {
        let limpia = texto.trimmingCharacters(in: .whitespaces).lowercased()
        guard !limpia.isEmpty, limpia.count <= 30 else { return }
        guard !etiquetas.contains(where: { $0.lowercased() == limpia }) else { return }
        etiquetas.append(String(limpia.prefix(30)))
        tocado()
    }
}

struct FichaMovimientoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo: FichaModelo
    var alAbrirOtro: (Int) -> Void = { _ in }
    @State private var hojaCategoria = false
    @State private var hojaHistorial = false
    @State private var hojaReportar = false
    @State private var dialogoDividir = false
    @State private var nuevaEtiqueta = ""
    @State private var procesandoDivision = false

    init(id: Int, alAbrirOtro: @escaping (Int) -> Void = { _ in }) {
        _modelo = StateObject(wrappedValue: FichaModelo(id: id))
        self.alAbrirOtro = alAbrirOtro
    }

    var body: some View {
        EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.detalle != nil) {
            if let d = modelo.detalle {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            cabecera(d)
                            bloqueNombre
                            bloqueInterruptores
                            bloqueEtiquetas
                            bloqueNota
                            if d.esDividido && !d.partes.isEmpty { bloquePartes(d) }
                            bloqueAcciones(d)
                            if let error = modelo.errorTexto {
                                Text(error)
                                    .font(.manrope(14))
                                    .foregroundStyle(Color.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            if let mensaje = modelo.mensajeGuardado {
                                Text(mensaje)
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(KipColor.elevated(scheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            Color.clear.frame(height: 16)
                        }
                    }
                    botonGuardar
                }
                .background(KipColor.bg(scheme))
            }
        } reintentar: {
            Task { await modelo.cargar() }
        }
        .navigationTitle(Text("Movimiento"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if modelo.detalle != nil {
                    Button { hojaReportar = true } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(KipColor.text(scheme))
                    }
                }
            }
        }
        .task { await modelo.cargar() }
        .sheet(isPresented: $hojaCategoria) {
            SelectorCategoriaFichaView(modelo: modelo)
        }
        .sheet(isPresented: $hojaHistorial) {
            if let d = modelo.detalle {
                HistorialComercioView(comercio: d.comercio) { otroId in
                    hojaHistorial = false
                    alAbrirOtro(otroId)
                }
            }
        }
        .sheet(isPresented: $hojaReportar) {
            if let d = modelo.detalle {
                ReportarMovimientoView(id: d.id, comercio: d.comercio, nombreCrudo: d.nombre,
                                       categoriaNombre: modelo.categoriaElegida?.nombre ?? "")
            }
        }
        .sheet(isPresented: $dialogoDividir) {
            if let d = modelo.detalle {
                DividirMovimientoView(modelo: modelo, total: d.monto) {
                    Task { await modelo.cargar() }
                }
            }
        }
    }

    private var botonGuardar: some View {
        Button {
            Task { await modelo.guardar() }
        } label: {
            Group {
                if modelo.guardando {
                    ProgressView().tint(KipColor.onAccent)
                } else {
                    Text("Guardar").font(.manrope(16, weight: .bold))
                }
            }
            .foregroundStyle(KipColor.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(KipColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(modelo.guardando)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KipColor.bg(scheme))
    }

    private func cabecera(_ d: MovimientoDetalle) -> some View {
        VStack(spacing: 8) {
            CirculoComercio(nombre: d.comercio, tamano: 64, logoUrl: d.logoUrl)
            Text(d.comercio)
                .font(.manrope(20, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .multilineTextAlignment(.center)
            if let nombre = d.nombre, !nombre.isEmpty, nombre != d.comercio {
                Text(nombre)
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
            }
            Text(d.montoTexto)
                .font(.manrope(36, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            Text(lineaContexto(d))
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .multilineTextAlignment(.center)
            if d.pendiente {
                Text("Este cobro todavía está pendiente en tu banco.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
            }
            if let pareja = d.pareja {
                if let etiqueta = pareja.etiqueta, !etiqueta.isEmpty {
                    Text(etiqueta)
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .multilineTextAlignment(.center)
                }
                if let texto = pareja.texto, !texto.isEmpty {
                    Text(texto)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                }
            }
            Button { hojaCategoria = true } label: {
                HStack(spacing: 8) {
                    CirculoIcono(simbolo: iconoDeCategoria(clave: modelo.categoriaElegida?.clave, icono: modelo.categoriaElegida?.icono),
                                 color: colorDeCategoria(hex: modelo.categoriaElegida?.color, clave: modelo.categoriaElegida?.clave), tamano: 30)
                    Text(modelo.categoriaElegida?.nombre ?? "")
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.text(scheme))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.leading, 8)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .background(KipColor.card(scheme))
                .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            if let original = d.categoriaOriginal, let claveOriginal = original.clave,
               claveOriginal != (modelo.categoriaClave ?? "") {
                Text("Tu banco lo marcó como: \(original.nombre ?? "")")
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
            }
            Divider().background(KipColor.border(scheme)).padding(.top, 8)
        }
        .padding(16)
    }

    private func lineaContexto(_ d: MovimientoDetalle) -> String {
        let fecha = d.fechaTexto.isEmpty ? fechaLegible(d.fecha) : d.fechaTexto
        var partesCuenta: [String] = []
        if let banco = d.cuenta?.banco, !banco.isEmpty { partesCuenta.append(banco) }
        if let nombre = d.cuenta?.nombre, !nombre.isEmpty { partesCuenta.append(nombre) }
        if let mascara = d.cuenta?.mascara, !mascara.isEmpty { partesCuenta.append("••••\(mascara)") }
        let cuenta = partesCuenta.joined(separator: " · ")
        return cuenta.isEmpty ? fecha : "\(fecha) · \(cuenta)"
    }

    private var bloqueNombre: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nombre que se muestra")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            CampoTextoPlano(texto: $modelo.nombreMostrar, placeholder: modelo.detalle?.comercio ?? "")
                .onChange(of: modelo.nombreMostrar) { _ in modelo.tocado() }
            Text("Si lo dejas vacío, se ve el nombre de tu banco.")
                .font(.manrope(12))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Divider().background(KipColor.border(scheme)).padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bloqueInterruptores: some View {
        VStack(spacing: 0) {
            filaInterruptor(titulo: "Transferencia entre mis cuentas",
                            subtitulo: "No cuenta como gasto ni como ingreso.",
                            valor: $modelo.esInterno)
            filaInterruptor(titulo: "Es un cobro recurrente",
                            subtitulo: "Márcalo si se repite cada mes o cada cierto tiempo.",
                            valor: $modelo.marcadaRecurrente)
            filaInterruptor(titulo: "Revisado",
                            subtitulo: "Ya lo revisaste y está bien.",
                            valor: $modelo.revisada)
            Text("Si cambias la categoría, aprendo: los próximos cargos de este comercio se clasifican solos con la que elijas.")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            Divider().background(KipColor.border(scheme))
        }
        .padding(.horizontal, 16)
    }

    private func filaInterruptor(titulo: String, subtitulo: String, valor: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Text(subtitulo)
                    .font(.manrope(12))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            KipInterruptor(activo: valor)
                .onChange(of: valor.wrappedValue) { _ in modelo.tocado() }
        }
        .padding(.vertical, 10)
    }

    private var bloqueEtiquetas: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Etiquetas")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            if !modelo.etiquetas.isEmpty {
                FlowEtiquetas(etiquetas: modelo.etiquetas) { etiqueta in
                    modelo.etiquetas.removeAll { $0 == etiqueta }
                    modelo.tocado()
                }
            }
            HStack(spacing: 10) {
                CampoTextoPlano(texto: $nuevaEtiqueta, placeholder: "Nueva etiqueta")
                Button("Agregar") {
                    modelo.agregarEtiqueta(nuevaEtiqueta)
                    nuevaEtiqueta = ""
                }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.horizontal, 16)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
            }
            Divider().background(KipColor.border(scheme)).padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bloqueNota: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tu nota")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            ZStack(alignment: .topLeading) {
                if modelo.nota.isEmpty {
                    Text("Escribe algo para recordar")
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $modelo.nota)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(minHeight: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
                    .onChange(of: modelo.nota) { _ in modelo.tocado() }
            }
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bloquePartes(_ d: MovimientoDetalle) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Partes de este movimiento")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.bottom, 4)
            ForEach(d.partes) { parte in
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: iconoDeCategoria(clave: parte.categoria?.clave, icono: parte.categoria?.icono),
                                 color: colorDeCategoria(hex: parte.categoria?.color, clave: parte.categoria?.clave), tamano: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(parte.descripcion ?? parte.comercio ?? parte.nombre ?? parte.categoria?.nombre ?? "Parte")
                            .font(.manrope(16))
                            .foregroundStyle(KipColor.text(scheme))
                        if let nombreCat = parte.categoria?.nombre {
                            Text(nombreCat)
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                    Spacer()
                    Text(parte.montoTexto ?? (parte.monto.map { dinero($0) } ?? ""))
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .padding(.vertical, 4)
            }
            Divider().background(KipColor.border(scheme)).padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bloqueAcciones(_ d: MovimientoDetalle) -> some View {
        VStack(spacing: 8) {
            botonBorde("Ver historial de este comercio") { hojaHistorial = true }
            if d.esDividido {
                botonBorde("Reunir las partes en un solo cargo") { reunir() }
            } else if d.monto > 0 {
                botonBorde("Dividir este cargo") { dialogoDividir = true }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func botonBorde(_ texto: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(procesandoDivision)
    }

    private func reunir() {
        procesandoDivision = true
        Task {
            do {
                _ = try await Api.reunirMovimiento(id: modelo.id)
                await modelo.cargar()
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.errorTexto = e.errorDescription
            }
            procesandoDivision = false
        }
    }
}

/// Un campo de texto plano con el estilo de CampoKip pero sin etiqueta
/// (para la ficha: nombre visible y nueva etiqueta).
struct CampoTextoPlano: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var texto: String
    var placeholder: String = ""

    var body: some View {
        TextField(placeholder, text: $texto)
            .font(.manrope(16))
            .foregroundStyle(KipColor.text(scheme))
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Las etiquetas puestas como pastillas con su ✕ (flujo simple en filas).
struct FlowEtiquetas: View {
    @Environment(\.colorScheme) private var scheme
    let etiquetas: [String]
    var alQuitar: (String) -> Void

    var body: some View {
        // Filas de hasta 3 por linea: suficiente para etiquetas cortas.
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filas, id: \.self) { fila in
                HStack(spacing: 8) {
                    ForEach(fila, id: \.self) { etiqueta in
                        HStack(spacing: 4) {
                            Text(etiqueta)
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.text(scheme))
                            Button {
                                alQuitar(etiqueta)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(KipColor.elevated(scheme))
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    private var filas: [[String]] {
        var resultado: [[String]] = []
        var actual: [String] = []
        for etiqueta in etiquetas {
            actual.append(etiqueta)
            if actual.count == 3 {
                resultado.append(actual)
                actual = []
            }
        }
        if !actual.isEmpty { resultado.append(actual) }
        return resultado
    }
}

// MARK: - Selector de categoria de la ficha

struct SelectorCategoriaFichaView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: FichaModelo

    var body: some View {
        NavigationStack {
            List {
                ForEach(modelo.categorias, id: \.clave) { categoria in
                    Button {
                        modelo.categoriaClave = categoria.clave
                        modelo.tocado()
                        cerrar()
                    } label: {
                        HStack(spacing: 12) {
                            CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                         color: colorDeCategoria(hex: categoria.color, clave: categoria.clave), tamano: 36)
                            Text(categoria.nombre ?? "")
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            if modelo.categoriaClave == categoria.clave {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(KipColor.gradientEnd)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(KipColor.bg(scheme))
                }
            }
            .listStyle(.plain)
            .navigationTitle(Text("Elige la categoría"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Historial del comercio

struct HistorialComercioView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    let comercio: String
    var alAbrir: (Int) -> Void = { _ in }
    @State private var datos: HistorialComercio? = nil
    @State private var cargando = true
    @State private var errorTexto: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    VStack { Spacer(); ProgressView().tint(KipColor.accent); Spacer() }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let datos = datos {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if (datos.veces ?? 0) == 0 {
                                Text("No hay otros movimientos de este comercio.")
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            } else {
                                Text("\(datos.veces ?? 0) veces · Total \(datos.totalGastoTexto ?? "") · Promedio \(datos.promedioTexto ?? "")")
                                    .font(.manrope(14))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                if let periodo = datos.periodo {
                                    Text("En total: \(datos.totalGastoTexto ?? "") en \(periodo.lapsoTexto ?? "") (del \(periodo.desdeTexto ?? "") al \(periodo.hastaTexto ?? "")).")
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.text(scheme))
                                }
                                if datos.porMes.count > 1 {
                                    barras(datos.porMes)
                                }
                                Divider().background(KipColor.border(scheme))
                                ForEach(datos.movimientos) { mov in
                                    Button {
                                        cerrar()
                                        alAbrir(mov.id)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(mov.comercio)
                                                    .font(.manrope(16))
                                                    .foregroundStyle(KipColor.text(scheme))
                                                Text(mov.fechaTexto)
                                                    .font(.manrope(12))
                                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                            }
                                            Spacer()
                                            Text(mov.montoTexto)
                                                .font(.manrope(16))
                                                .foregroundStyle(KipColor.text(scheme))
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    Divider().background(KipColor.border(scheme))
                                }
                            }
                        }
                        .padding(16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Text(errorTexto ?? "No se pudo cargar el historial.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(KipColor.bg(scheme))
            .navigationTitle(Text("Historial de \(comercio)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
        .task { await cargar() }
    }

    private func barras(_ meses: [HistorialMes]) -> some View {
        let maximo = max(meses.compactMap { $0.total }.max() ?? 0, 0.01)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(meses, id: \.mes) { mes in
                    VStack(spacing: 4) {
                        Text(mes.totalTexto ?? "")
                            .font(.manrope(11, weight: .heavy))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KipColor.accent)
                            .frame(width: 30, height: max(4, 56 * CGFloat((mes.total ?? 0) / maximo)))
                        Text(mes.etiqueta ?? "")
                            .font(.manrope(11))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
            }
        }
    }

    private func cargar() async {
        cargando = true
        do {
            datos = try await Api.historialComercio(comercio: comercio)
            cargando = false
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
        } catch {
            errorTexto = "No se pudo cargar el historial."
            cargando = false
        }
    }
}

// MARK: - Reportar un problema

struct ReportarMovimientoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    let id: Int
    let comercio: String
    let nombreCrudo: String?
    let categoriaNombre: String
    @State private var noEsComercio = false
    @State private var noEsCategoria = false
    @State private var detalle = ""
    @State private var enviando = false
    @State private var errorTexto: String? = nil
    @State private var enviado: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let enviado = enviado {
                        Text(enviado)
                            .font(.manrope(16))
                            .foregroundStyle(KipColor.text(scheme))
                        Button("Cerrar") { cerrar() }
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.gradientEnd)
                    } else {
                        Text("Comercio: \(comercio)")
                            .font(.manrope(16))
                            .foregroundStyle(KipColor.text(scheme))
                        if let nombre = nombreCrudo, !nombre.isEmpty, nombre != comercio {
                            Text("En tu estado de cuenta: \(nombre)")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Text("Categoría: \(categoriaNombre)")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        casilla("No es este comercio", valor: $noEsComercio)
                        casilla("No es esta categoría", valor: $noEsCategoria)
                        Text("Detalles (opcional)")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $detalle)
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                                .frame(minHeight: 70)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .scrollContentBackground(.hidden)
                        }
                        .background(KipColor.card(scheme))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        if let error = errorTexto {
                            Text(error)
                                .font(.manrope(14))
                                .foregroundStyle(Color.red)
                        }
                        HStack(spacing: 12) {
                            Button("Cancelar") { cerrar() }
                                .font(.manrope(15, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
                            Button(enviando ? "Enviando…" : "Enviar") { enviar() }
                                .font(.manrope(15, weight: .bold))
                                .foregroundStyle(KipColor.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(KipColor.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .disabled((!noEsComercio && !noEsCategoria && detalle.trimmingCharacters(in: .whitespaces).isEmpty) || enviando)
                                .opacity((!noEsComercio && !noEsCategoria && detalle.trimmingCharacters(in: .whitespaces).isEmpty) || enviando ? 0.5 : 1)
                        }
                    }
                }
                .padding(16)
            }
            .background(KipColor.bg(scheme))
            .navigationTitle(Text("Reportar un problema con el dato"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func casilla(_ texto: String, valor: Binding<Bool>) -> some View {
        Button {
            valor.wrappedValue.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: valor.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(valor.wrappedValue ? KipColor.accent : KipColor.textSecondary(scheme))
                Text(texto)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func enviar() {
        enviando = true
        errorTexto = nil
        Task {
            do {
                let r = try await Api.reportarMovimiento(id: id, cuerpo: [
                    "no_es_comercio": noEsComercio,
                    "no_es_categoria": noEsCategoria,
                    "detalle": detalle.trimmingCharacters(in: .whitespaces).isEmpty ? NSNull() : detalle.trimmingCharacters(in: .whitespaces),
                ])
                enviado = r.mensaje ?? "Gracias: tu reporte quedó enviado."
                enviando = false
            } catch let e as ApiError {
                enviando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorTexto = e.errorDescription ?? "No se pudo enviar tu reporte."
            }
        }
    }
}

// MARK: - Dividir el cargo

struct DividirMovimientoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: FichaModelo
    let total: Double
    var alTerminar: () -> Void = {}
    @State private var partes: [ParteEdicion] = [ParteEdicion(), ParteEdicion()]
    @State private var dividiendo = false
    @State private var errorTexto: String? = nil
    @State private var parteCategoria: Int? = nil

    struct ParteEdicion: Identifiable {
        let id = UUID()
        var montoTexto = ""
        var categoria: CategoriaMov? = nil
        var monto: Double { Double(montoTexto.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Total del cargo: \(dinero(total))")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    ForEach(partes.indices, id: \.self) { i in
                        HStack(spacing: 10) {
                            CampoTextoPlano(texto: $partes[i].montoTexto, placeholder: "Monto")
                            Button(partes[i].categoria?.nombre ?? "Categoría") { parteCategoria = i }
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
                            if partes.count > 2 {
                                Button {
                                    partes.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if partes.count < 6 {
                        Button("Agregar otra parte") { partes.append(ParteEdicion()) }
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.gradientEnd)
                    }
                    Text(pieValidacion)
                        .font(.manrope(14))
                        .foregroundStyle(cuadra ? KipColor.gradientEnd : Color.red)
                    if let error = errorTexto {
                        Text(error)
                            .font(.manrope(14))
                            .foregroundStyle(Color.red)
                    }
                }
                .padding(16)
            }
            .background(KipColor.bg(scheme))
            .navigationTitle(Text("Dividir este cargo"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dividir") { dividir() }
                        .disabled(!cuadra || dividiendo)
                }
            }
            .sheet(isPresented: Binding(get: { parteCategoria != nil }, set: { if !$0 { parteCategoria = nil } })) {
                NavigationStack {
                    List {
                        ForEach(modelo.categorias, id: \.clave) { categoria in
                            Button {
                                if let i = parteCategoria { partes[i].categoria = categoria }
                                parteCategoria = nil
                            } label: {
                                HStack(spacing: 12) {
                                    CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                                 color: colorDeCategoria(hex: categoria.color, clave: categoria.clave), tamano: 32)
                                    Text(categoria.nombre ?? "")
                                        .font(.manrope(16))
                                        .foregroundStyle(KipColor.text(scheme))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(KipColor.bg(scheme))
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle(Text("Categoría de la parte"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private var suma: Double { partes.reduce(0) { $0 + $1.monto } }

    private var cuadra: Bool {
        abs(suma - total) < 0.005 && partes.allSatisfy { $0.monto > 0 && $0.categoria != nil }
    }

    private var pieValidacion: String {
        var texto = "Suma de las partes: \(dinero(suma))"
        if !cuadra {
            texto += " — debe dar el total del cargo, y cada parte necesita su categoría."
        }
        return texto
    }

    private func dividir() {
        dividiendo = true
        errorTexto = nil
        let cuerpo: [[String: Any]] = partes.map { parte in
            var p: [String: Any] = ["monto": parte.monto]
            if let clave = parte.categoria?.clave { p["categoria"] = clave }
            return p
        }
        Task {
            do {
                _ = try await Api.dividirMovimiento(id: modelo.id, partes: cuerpo)
                cerrar()
                alTerminar()
            } catch let e as ApiError {
                dividiendo = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorTexto = e.errorDescription
            }
        }
    }
}
