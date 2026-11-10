import SwiftUI

// La pantalla Presupuesto (PresupuestoScreen.kt + AdministrarPresupuestoScreen.kt
// + HojasPresupuesto.kt de la Android): barra del mes, cierre del mes
// pasado, heroe del resumen, servicios, ingresos, meta, presupuestos
// por categoria con su anillo, "Todo lo demas" desplegable y las FAQ.
// Administrar reemplaza a la principal (no es hoja) y las 6 hojas son
// modales: opciones x2, agregar con buscador, editar tope, editar
// ingreso y crear categoria. El servidor es la unica verdad: toda
// escritura devuelve la pantalla entera y el modelo la sustituye.

/// El mes "yyyy-MM" desplazado n meses (la navegacion parte del mes de
/// la RESPUESTA, no de un estado local).
func mesDesplazado(_ mes: String, delta: Int) -> String {
    let partes = mes.split(separator: "-")
    guard partes.count == 2, let anio = Int(partes[0]), let m = Int(partes[1]) else { return mes }
    var total = anio * 12 + (m - 1) + delta
    if total < 0 { total = 0 }
    return String(format: "%04d-%02d", total / 12, total % 12 + 1)
}

/// El monto tecleado a numero: acepta coma como separador decimal,
/// como la Android.
func montoDesdeTexto(_ texto: String) -> Double? {
    let limpio = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    if limpio.isEmpty { return nil }
    return Double(limpio)
}

/// Los datos de entrada de la hoja de edicion del tope, armados por el
/// cliente desde la fila o desde el catalogo de disponibles.
struct TopeEditable: Identifiable {
    var id: String { clave }
    let clave: String
    let etiqueta: String
    let icono: String
    let color: String
    let idPresupuesto: Int?
    let limite: Double?
    let promedio: Double
    let promedioTexto: String
    let historial: [HistorialPresupuesto]
}

func topeEditable(desdeFila fila: PresupuestoPantallaFila, datos: PresupuestoPantalla) -> TopeEditable {
    let disponible = datos.categoriasDisponibles.first { $0.clave == fila.categoria }
    return TopeEditable(clave: fila.categoria, etiqueta: fila.etiqueta, icono: fila.categoriaIcono,
                        color: fila.categoriaColor, idPresupuesto: fila.id, limite: fila.limite,
                        promedio: disponible?.promedio ?? 0, promedioTexto: disponible?.promedioTexto ?? "",
                        historial: fila.historial)
}

func topeEditable(desdeDisponible disponible: CategoriaDisponible) -> TopeEditable {
    TopeEditable(clave: disponible.clave, etiqueta: disponible.etiqueta, icono: disponible.icono,
                 color: disponible.color, idPresupuesto: nil, limite: nil,
                 promedio: disponible.promedio, promedioTexto: disponible.promedioTexto, historial: [])
}

@MainActor
final class PresupuestoModelo: ObservableObject {
    @Published var datos: PresupuestoPantalla? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    /// El error de una escritura: se pinta DENTRO de la hoja (o en la
    /// lista de Administrar) y la hoja no se cierra.
    @Published var errorAccion: String? = nil
    @Published var accionEnCurso = false
    /// Solo sube con escrituras exitosas (guardar/quitar/reiniciar): la
    /// vista lo observa para cerrar todas las hojas y Administrar.
    @Published var guardadoTick = 0
    /// La clave a editar al llegar desde el detalle de categoria; la
    /// pantalla la consume en cuanto hay datos.
    var clavePendiente: String? = nil

    func cargar(mes: String?) async {
        cargando = true
        errorTexto = nil
        do {
            datos = try await Api.presupuesto(mes: mes)
            cargando = false
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            if datos == nil { errorTexto = e.errorDescription }
            cargando = false
        } catch {
            if datos == nil { errorTexto = "Algo salió mal. Intenta de nuevo." }
            cargando = false
        }
    }

    func irMes(delta: Int) async {
        guard let actual = datos else { return }
        await cargar(mes: mesDesplazado(actual.mes, delta: delta))
    }

    /// Ejecuta una escritura de pantalla entera: sustituye los datos,
    /// sube el tick (la vista cierra hojas y Administrar) y, si falla,
    /// deja el error en errorAccion sin cerrar nada.
    private func ejecutarEscritura(_ operacion: @escaping () async throws -> PresupuestoPantalla) async {
        if accionEnCurso { return }
        accionEnCurso = true
        errorAccion = nil
        do {
            datos = try await operacion()
            accionEnCurso = false
            guardadoTick += 1
        } catch let e as ApiError {
            accionEnCurso = false
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorAccion = e.errorDescription
        } catch {
            accionEnCurso = false
            errorAccion = "Algo salió mal. Intenta de nuevo."
        }
    }

    func guardarTope(clave: String, limite: Double) async {
        guard let mes = datos?.mes else { return }
        await ejecutarEscritura { try await Api.guardarPresupuesto(categoria: clave, mes: mes, limite: limite) }
    }

    func guardarIngreso(_ ingreso: Double) async {
        guard let mes = datos?.mes else { return }
        await ejecutarEscritura { try await Api.guardarPlanPresupuesto(mes: mes, ingreso: ingreso) }
    }

    func reiniciar() async {
        guard let mes = datos?.mes else { return }
        await ejecutarEscritura { try await Api.reiniciarPresupuesto(mes: mes) }
    }

    func quitarTope(id: Int) async {
        await ejecutarEscritura { try await Api.quitarPresupuesto(id: id) }
    }

    /// Crear categoria NO sube el tick: recarga el mes en curso y
    /// devuelve el TopeEditable de la recien creada para abrir su hoja
    /// de edicion. Si la recarga falla, igual devuelve la clave buscada
    /// en los datos viejos y deja el error de carga en errorTexto.
    func crearCategoria(nombre: String, color: String, icono: String) async -> TopeEditable? {
        if accionEnCurso { return nil }
        accionEnCurso = true
        errorAccion = nil
        do {
            let creada = try await Api.crearCategoriaPersonalizada(cuerpo: [
                "nombre": nombre, "color": color, "icono": icono, "tipo": "gasto",
            ])
            accionEnCurso = false
            guard let clave = creada.categoria?.clave else { return nil }
            await cargar(mes: datos?.mes)
            if let datos = datos {
                if let fila = datos.filas.first(where: { $0.categoria == clave }) {
                    return topeEditable(desdeFila: fila, datos: datos)
                }
                if let disponible = datos.categoriasDisponibles.first(where: { $0.clave == clave }) {
                    return topeEditable(desdeDisponible: disponible)
                }
            }
            return nil
        } catch let e as ApiError {
            accionEnCurso = false
            if case .sesionTerminada = e { Sesion.cerrar(); return nil }
            errorAccion = e.errorDescription
            return nil
        } catch {
            accionEnCurso = false
            errorAccion = "Algo salió mal. Intenta de nuevo."
            return nil
        }
    }

    /// Consume la clave pendiente (entrada desde el detalle de
    /// categoria) y arma su TopeEditable con los datos ya cargados.
    func consumirClavePendiente() -> TopeEditable? {
        guard let clave = clavePendiente, let datos = datos else { return nil }
        clavePendiente = nil
        if let fila = datos.filas.first(where: { $0.categoria == clave }) {
            return topeEditable(desdeFila: fila, datos: datos)
        }
        if let disponible = datos.categoriasDisponibles.first(where: { $0.clave == clave }) {
            return topeEditable(desdeDisponible: disponible)
        }
        return nil
    }
}

// MARK: - FAQ (contenido local, el mismo texto de la Android)

let PREGUNTAS_PRESUPUESTO: [(pregunta: String, respuesta: String)] = [
    ("¿Cómo se calcula tu plan?",
     "Sumamos los topes que pusiste por categoría: ese es tu plan del mes. Si en Administrar declaras cuánto esperas que entre, restamos el plan de ese ingreso y lo que sobre es lo que queda para ahorro y deudas. Si el plan reparte más de lo que entra, te lo avisamos ahí mismo."),
    ("¿Qué entra en el gasto?",
     "Todos los cargos de tus cuentas conectadas. No cuentan los movimientos entre tus propias cuentas ni los pagos de tus tarjetas: ese dinero ya se contó cuando hiciste la compra, y contarlo otra vez duplicaría el gasto."),
    ("¿Cómo funcionan los presupuestos por categoría?",
     "A cada categoría le pones un tope fijo: lo fijas una vez y te acomodas a él mes con mes. Conforme llegan cargos de esa categoría, el anillo se llena y el aviso cambia al acercarte al límite. Si corriges la categoría de un cargo, Kipwallet aprende y la próxima vez lo clasifica solo."),
    ("¿Qué es el promedio al crear un límite?",
     "Lo que gastaste en esa categoría en los últimos 6 meses, dividido entre 6. Es un punto de partida honesto: si tu promedio es $450, un límite de $200 quizá sea demasiado apretado para el primer mes."),
]

struct TarjetaFAQPresupuesto: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var expandida: Bool
    @State private var abierta: Int? = nil

    var body: some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Button { expandida.toggle() } label: {
                    HStack {
                        Text("Preguntas frecuentes")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer()
                        Image(systemName: expandida ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if expandida {
                    ForEach(Array(PREGUNTAS_PRESUPUESTO.enumerated()), id: \.offset) { indice, par in
                        Divider().background(KipColor.border(scheme))
                        Button { abierta = abierta == indice ? nil : indice } label: {
                            HStack {
                                Text(par.pregunta)
                                    .font(.manrope(15, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: abierta == indice ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if abierta == indice {
                            Text(par.respuesta)
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Pantalla principal

struct PresupuestoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrarVista
    /// La clave a editar al entrar desde el detalle de categoria (nil
    /// desde el mosaico de Mas): al llegar los datos se abre directa la
    /// hoja de edicion del tope de esa categoria.
    var claveEditar: String? = nil
    var alAbrirCategoria: (String) -> Void = { _ in }

    @StateObject private var modelo = PresupuestoModelo()
    @State private var administrar = false
    @State private var hojaOpcionesPrincipal = false
    @State private var hojaOpcionesAdministrar = false
    @State private var hojaAgregar = false
    @State private var topeItem: TopeEditable? = nil
    @State private var hojaIngreso = false
    @State private var confirmarReinicio = false
    @State private var avisoMetas = false
    @State private var faqPrincipal = false
    @State private var faqAdministrar = false
    @State private var todoLoDemasAbierto = false

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
                if let datos = modelo.datos {
                    if administrar {
                        AdministrarPresupuestoView(modelo: modelo, datos: datos,
                                                   faqExpandida: $faqAdministrar,
                                                   alOpciones: { hojaOpcionesAdministrar = true },
                                                   alEditarTope: { topeItem = $0 },
                                                   alEditarIngreso: { hojaIngreso = true },
                                                   alCrearMeta: { avisoMetas = true })
                    } else {
                        principal(datos)
                    }
                }
            } reintentar: {
                Task { await modelo.cargar(mes: modelo.datos?.mes) }
            }
        }
        .background(KipColor.bg(scheme))
        .task {
            if modelo.datos == nil {
                modelo.clavePendiente = claveEditar
                await modelo.cargar(mes: nil)
                if let tope = modelo.consumirClavePendiente() { topeItem = tope }
            }
        }
        // Toda escritura exitosa cierra las hojas y Administrar.
        .onChange(of: modelo.guardadoTick) { _ in
            hojaOpcionesPrincipal = false
            hojaOpcionesAdministrar = false
            hojaAgregar = false
            topeItem = nil
            hojaIngreso = false
            administrar = false
        }
        .sheet(isPresented: $hojaOpcionesPrincipal) {
            HojaOpcionesPresupuesto(alAdministrar: { hojaOpcionesPrincipal = false; administrar = true },
                                    alAgregar: { hojaOpcionesPrincipal = false; hojaAgregar = true })
        }
        .sheet(isPresented: $hojaOpcionesAdministrar) {
            HojaOpcionesAdministrar(alAgregar: { hojaOpcionesAdministrar = false; hojaAgregar = true },
                                    alFAQ: { hojaOpcionesAdministrar = false; faqAdministrar = true },
                                    alReiniciar: { hojaOpcionesAdministrar = false; confirmarReinicio = true })
        }
        .sheet(isPresented: $hojaAgregar) {
            HojaAgregarPresupuesto(modelo: modelo)
        }
        .sheet(item: $topeItem) { tope in
            HojaEditarTope(modelo: modelo, tope: tope)
        }
        .sheet(isPresented: $hojaIngreso) {
            HojaEditarIngreso(modelo: modelo)
        }
        .alert("¿Empezar de nuevo?", isPresented: $confirmarReinicio) {
            Button("Cancelar", role: .cancel) {}
            Button("Empezar de nuevo", role: .destructive) {
                Task { await modelo.reiniciar() }
            }
            .disabled(modelo.accionEnCurso)
        } message: {
            Text("Se borran TODOS tus topes (valen para todos los meses) y el ingreso esperado de \((modelo.datos?.mesEtiqueta ?? "").lowercased()). Tus movimientos y tus categorías no se tocan.")
        }
        // Metas aun no existe en iOS: el mismo aviso honesto de Mas.
        .alert("En construcción", isPresented: $avisoMetas) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("La pantalla Metas se construye en la siguiente ronda, igual que en tu Android.")
        }
    }

    private var cabecera: some View {
        HStack(spacing: 4) {
            Button {
                if administrar { administrar = false } else { cerrarVista() }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Volver")
                        .font(.manrope(16, weight: .semibold))
                }
                .foregroundStyle(KipColor.text(scheme))
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            Text(administrar ? "Administrar presupuesto" : "Presupuesto")
                .font(.manrope(24, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            if modelo.datos != nil {
                Button {
                    if administrar { hojaOpcionesAdministrar = true } else { hojaOpcionesPrincipal = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Opciones")
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: Bloques de la principal, en el orden de la Android

    private func principal(_ datos: PresupuestoPantalla) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                barraMes(datos)
                if let cierre = datos.cierre { tarjetaCierre(datos, cierre: cierre) }
                tarjetaHeroe(datos)
                tarjetaServicios(datos)
                tarjetaIngresos(datos)
                tarjetaMeta(datos)
                tarjetaCategorias(datos)
                TarjetaFAQPresupuesto(expandida: $faqPrincipal)
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
        .refreshable { await modelo.cargar(mes: datos.mes) }
    }

    private func barraMes(_ datos: PresupuestoPantalla) -> some View {
        KipCard {
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(datos.esMesActual ? "Este mes" : datos.mesEtiqueta)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Button { Task { await modelo.irMes(delta: -1) } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes anterior")
                Button { Task { await modelo.irMes(delta: 1) } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mes siguiente")
            }
        }
    }

    private func tarjetaCierre(_ datos: PresupuestoPantalla, cierre: CierrePresupuesto) -> some View {
        let maximo = max(cierre.entro, cierre.salio, 1)
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Así cerró \(datos.mesEtiqueta.lowercased())")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                barraCierre(etiqueta: "Entró", texto: cierre.entroTexto, fraccion: cierre.entro / maximo, color: KipColor.accent)
                barraCierre(etiqueta: "Salió", texto: cierre.salioTexto, fraccion: cierre.salio / maximo, color: Color(hex: 0x5B8DEF))
                Text("Te quedó: \(cierre.teQuedoTexto)")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(cierre.teQuedo < 0 ? Color.red : KipColor.text(scheme))
                Text(cierre.teQuedo >= 0
                     ? "Cerraste el mes en positivo."
                     : "Gastaste más de lo que entró; le pasa a cualquiera, y verlo es el primer paso.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                ForEach(cierre.filas) { fila in
                    HStack(spacing: 10) {
                        CirculoIcono(simbolo: iconoDeCategoria(clave: fila.clave, icono: fila.categoriaIcono),
                                     color: colorDeCategoria(hex: fila.categoriaColor, clave: fila.clave), tamano: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fila.etiqueta)
                                .font(.manrope(15, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text(lineaCierre(fila))
                                .font(.manrope(13))
                                .foregroundStyle(fila.veredicto == "sobre" ? Color.red : KipColor.textSecondary(scheme))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func barraCierre(etiqueta: String, texto: String, fraccion: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(etiqueta)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Text(texto)
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            BarraProgreso(fraccion: fraccion, color: color)
        }
    }

    private func lineaCierre(_ fila: CierreFila) -> String {
        switch fila.veredicto {
        case "bajo":
            return "Gastaste \(fila.gastadoTexto) de \(fila.limiteTexto) · quedó bajo por \(fila.diferenciaTexto)"
        case "sobre":
            // El importe positivo lo formatea el cliente: el servidor
            // manda la diferencia con signo en diferencia_texto.
            return "Gastaste \(fila.gastadoTexto) de \(fila.limiteTexto) · se pasó por \(dinero(abs(fila.diferencia)))"
        default:
            return "Gastaste \(fila.gastadoTexto) · sin límite"
        }
    }

    private func tarjetaHeroe(_ datos: PresupuestoPantalla) -> some View {
        KipCard {
            if datos.hayPresupuesto {
                let resumen = datos.resumen
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        CirculoIcono(simbolo: "wallet.pass.fill", color: KipColor.gradientEnd, tamano: 36)
                        Spacer()
                        if let porDia = resumen.porDiaTexto {
                            ChipSuave(texto: "\(porDia)/día por \(resumen.diasRestantes) días", color: KipColor.gradientEnd)
                        }
                    }
                    Text("Te quedan \(resumen.teQuedaTexto) por gastar")
                        .font(.manrope(20, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    BarraProgreso(fraccion: (resumen.porcentaje ?? 0) / 100,
                                  color: (resumen.porcentaje ?? 0) >= 100 ? Color.red : KipColor.accent)
                    HStack {
                        Text("Gastado: \(resumen.totalGastadoTexto)")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Spacer()
                        Text("Presupuestado: \(resumen.totalLimitesTexto)")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Todavía no tienes presupuestos")
                        .font(.manrope(20, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Ponle un tope a cada categoría y aquí verás cuánto te queda por gastar.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    BotonPrimario(texto: "Agregar presupuesto") { hojaAgregar = true }
                }
            }
        }
    }

    private func tarjetaServicios(_ datos: PresupuestoPantalla) -> some View {
        let servicios = datos.servicios
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: "doc.text.fill", color: KipPastel.indigo, tamano: 36)
                    Text("Servicios y facturas")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                Text("Te quedan \(servicios.restanteTexto) por pagar")
                    .font(.manrope(17, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                BarraProgreso(fraccion: servicios.esperado > 0 ? servicios.cobrado / servicios.esperado : 0,
                              color: KipColor.accent)
                Text("Ya se cobraron \(servicios.cobradoTexto) de \(servicios.esperadoTexto) este mes.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private func tarjetaIngresos(_ datos: PresupuestoPantalla) -> some View {
        let esperado = datos.plan.ingresoEfectivo
        let entrado = datos.ingresos.total
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: "dollarsign.circle.fill", color: KipColor.gradientEnd, tamano: 36)
                    Text("Ingresos")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if esperado > 0 {
                    Text(entrado >= esperado
                         ? "Ya entró todo lo que esperabas"
                         : "Te quedan \(dinero(esperado - entrado)) por entrar")
                        .font(.manrope(17, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    BarraProgreso(fraccion: entrado / esperado, color: KipColor.accent)
                    Text("Ya entraron \(datos.ingresos.totalTexto) de \(datos.plan.ingresoEfectivoTexto) que esperas\(datos.plan.ingresoEsSugerido ? " (según el mes pasado)." : ".")")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                } else {
                    Text(datos.ingresos.totalTexto)
                        .font(.manrope(20, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Ya entró este mes.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
        }
    }

    private func tarjetaMeta(_ datos: PresupuestoPantalla) -> some View {
        let meta = datos.metaAhorro
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: "banknote.fill", color: KipColor.gradientEnd, tamano: 36)
                    Text(meta.hayMeta ? "Meta: \(meta.nombre ?? "")" : "Meta de ahorro")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if meta.hayMeta {
                    Text("Ahorro proyectado: \(meta.proyectadoTexto ?? "")")
                        .font(.manrope(17, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    BarraProgreso(fraccion: (meta.porcentaje ?? 0) / 100, color: KipColor.accent)
                    Text("Llevas \(meta.ahorradoTexto ?? "") de \(meta.objetivoTexto ?? "").")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    if let mensaje = meta.mensaje, !mensaje.isEmpty {
                        Text(mensaje)
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                } else {
                    Text("Crea una meta y aquí verás cuánto podrías ahorrar este mes sin salirte de tu presupuesto.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Button("Crear una meta") { avisoMetas = true }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
            }
        }
    }

    private func tarjetaCategorias(_ datos: PresupuestoPantalla) -> some View {
        let conTope = datos.filas.filter { $0.limite != nil }
        return KipCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Presupuestos por categoría")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    Button("Agregar") { hojaAgregar = true }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 4)
                ForEach(conTope, id: \.categoria) { fila in
                    Divider().background(KipColor.border(scheme)).padding(.leading, 72)
                    filaPresupuesto(fila)
                }
                if datos.todoLoDemas.cantidad > 0 {
                    Divider().background(KipColor.border(scheme)).padding(.leading, 72)
                    filaTodoLoDemas(datos)
                }
                Divider().background(KipColor.border(scheme)).padding(.leading, 72)
                Button { hojaAgregar = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(KipColor.gradientEnd)
                        Text("Agregar presupuesto")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func filaPresupuesto(_ fila: PresupuestoPantallaFila) -> some View {
        let color = colorDeCategoria(hex: fila.categoriaColor, clave: fila.categoria)
        let excedido = fila.alerta == "excedido"
        return Button { alAbrirCategoria(fila.categoria) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(KipColor.border(scheme), lineWidth: 4.5)
                    Circle()
                        .trim(from: 0, to: min(max((fila.porcentaje ?? 0) / 100, 0), 1))
                        .stroke(excedido ? Color.red : color,
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: iconoDeCategoria(clave: fila.categoria, icono: fila.categoriaIcono))
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fila.etiqueta)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .lineLimit(1)
                    Text(textoQuedaFila(fila))
                        .font(.manrope(14))
                        .foregroundStyle(excedido ? Color.red : KipColor.textSecondary(scheme))
                }
                Spacer(minLength: 4)
                Text(fila.gastadoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func textoQuedaFila(_ fila: PresupuestoPantallaFila) -> String {
        if let queda = fila.queda {
            if queda >= 0 { return "Te quedan \(fila.quedaTexto ?? "")" }
            // El importe positivo lo formatea el cliente.
            return "Te pasaste por \(dinero(abs(queda)))"
        }
        return ""
    }

    private func filaTodoLoDemas(_ datos: PresupuestoPantalla) -> some View {
        let demas = datos.todoLoDemas
        return VStack(spacing: 0) {
            Button { todoLoDemasAbierto.toggle() } label: {
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: iconoDeCategoria(clave: "OTHER", icono: "etiqueta"),
                                 color: colorDeCategoria(hex: nil, clave: "OTHER"), tamano: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Todo lo demás")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(demas.cantidad == 1
                             ? "1 categoría sin presupuesto este mes"
                             : "\(demas.cantidad) categorías sin presupuesto este mes")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer(minLength: 4)
                    Text(demas.gastadoTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Image(systemName: todoLoDemasAbierto ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todoLoDemasAbierto ? "Cerrar" : "Ver el detalle")
            if todoLoDemasAbierto {
                ForEach(demas.filas, id: \.categoria) { fila in
                    Button { alAbrirCategoria(fila.categoria) } label: {
                        HStack(spacing: 12) {
                            CirculoIcono(simbolo: iconoDeCategoria(clave: fila.categoria, icono: fila.categoriaIcono),
                                         color: colorDeCategoria(hex: fila.categoriaColor, clave: fila.categoria), tamano: 32)
                            Text(fila.etiqueta)
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                                .lineLimit(1)
                            Spacer()
                            Text(fila.gastadoTexto)
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Administrar presupuesto (reemplaza a la principal)

struct AdministrarPresupuestoView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: PresupuestoModelo
    let datos: PresupuestoPantalla
    @Binding var faqExpandida: Bool
    var alOpciones: () -> Void = {}
    var alEditarTope: (TopeEditable) -> Void = { _ in }
    var alEditarIngreso: () -> Void = {}
    var alCrearMeta: () -> Void = {}
    @State private var gastosExpandida = true

    private var filasConTope: [PresupuestoPantallaFila] { datos.filas.filter { $0.limite != nil } }
    private var sumaMesPasado: Double { filasConTope.reduce(0) { $0 + $1.mesPasado } }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                tarjetaIngresos
                rotulo(titulo: "DESGLOSE DEL PRESUPUESTO",
                       total: "Total: \(dinero(datos.servicios.esperado + datos.plan.totalAsignado))",
                       rojo: false)
                tarjetaServicios
                if datos.plan.pagoDeudas > 0 { tarjetaDeudas }
                tarjetaGastos
                rotulo(titulo: "LO QUE QUEDA PARA AHORRO",
                       total: "Total: \(datos.plan.quedaParaAhorroTexto)",
                       rojo: datos.plan.sobreComprometido)
                tarjetaMeta
                if let error = modelo.errorAccion {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                TarjetaFAQPresupuesto(expandida: $faqExpandida)
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    private func rotulo(titulo: String, total: String, rojo: Bool) -> some View {
        HStack {
            Text(titulo)
                .font(.manrope(12, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            Text(total)
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(rojo ? Color.red : KipColor.gradientEnd)
        }
    }

    private func filaAdmin(simbolo: String, color: Color, titulo: String, subtitulo: String, valor: String) -> some View {
        HStack(spacing: 12) {
            CirculoIcono(simbolo: simbolo, color: color, tamano: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(subtitulo)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer(minLength: 4)
            Text(valor)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
    }

    private var tarjetaIngresos: some View {
        let plan = datos.plan
        return KipCard {
            HStack(spacing: 12) {
                CirculoIcono(simbolo: "dollarsign.circle.fill", color: KipColor.gradientEnd, tamano: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ingresos")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("\(plan.ingresoMesPasadoTexto) el mes pasado\(plan.ingresoEsSugerido ? " · aún no lo fijas" : "")")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                Spacer(minLength: 4)
                Text(plan.ingresoEfectivoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Button { alEditarIngreso() } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(modelo.accionEnCurso)
                .accessibilityLabel("Editar ingreso esperado")
            }
        }
    }

    private var tarjetaServicios: some View {
        let servicios = datos.servicios
        return KipCard {
            filaAdmin(simbolo: "doc.text.fill", color: KipPastel.indigo, titulo: "Servicios y facturas",
                      subtitulo: "Ya se cobraron \(servicios.cobradoTexto) de \(servicios.esperadoTexto) este mes",
                      valor: servicios.esperadoTexto)
        }
    }

    private var tarjetaDeudas: some View {
        let plan = datos.plan
        var subtitulo = "Mínimos de este mes: \(plan.pagoDeudasMinimosTexto)"
        if plan.pagoDeudasExtra > 0 {
            subtitulo += " · Extra de tu plan de deudas: \(plan.pagoDeudasExtraTexto)"
        }
        subtitulo += ". Ya está apartado: sale antes de repartir."
        return KipCard {
            filaAdmin(simbolo: "creditcard.fill", color: KipPastel.indigo, titulo: "Pago de deudas",
                      subtitulo: subtitulo, valor: plan.pagoDeudasTexto)
        }
    }

    private var tarjetaGastos: some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Button { gastosExpandida.toggle() } label: {
                    HStack(spacing: 12) {
                        CirculoIcono(simbolo: "wallet.pass.fill", color: KipColor.gradientEnd, tamano: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gastos")
                                .font(.manrope(16, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("\(dinero(sumaMesPasado)) el mes pasado")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer(minLength: 4)
                        Text(datos.plan.totalAsignadoTexto)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Image(systemName: gastosExpandida ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if gastosExpandida {
                    if filasConTope.isEmpty {
                        Text("Este mes no tienes presupuestos todavía. Agrega el primero desde el menú de arriba.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    } else {
                        ForEach(filasConTope, id: \.categoria) { fila in
                            Divider().background(KipColor.border(scheme)).padding(.leading, 68)
                            HStack(spacing: 12) {
                                CirculoIcono(simbolo: iconoDeCategoria(clave: fila.categoria, icono: fila.categoriaIcono),
                                             color: colorDeCategoria(hex: fila.categoriaColor, clave: fila.categoria), tamano: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fila.etiqueta)
                                        .font(.manrope(16, weight: .bold))
                                        .foregroundStyle(KipColor.text(scheme))
                                        .lineLimit(1)
                                    Text("\(fila.mesPasadoTexto) el mes pasado")
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer(minLength: 4)
                                Text(fila.limiteTexto ?? "")
                                    .font(.manrope(16, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                                Button { alEditarTope(topeEditable(desdeFila: fila, datos: datos)) } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(KipColor.text(scheme))
                                        .frame(width: 36, height: 36)
                                }
                                .buttonStyle(.plain)
                                .disabled(modelo.accionEnCurso)
                                .accessibilityLabel("Editar presupuesto de \(fila.etiqueta)")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        Color.clear.frame(height: 6)
                    }
                } else if !filasConTope.isEmpty {
                    HStack(spacing: 0) {
                        ZStack(alignment: .leading) {
                            ForEach(Array(filasConTope.prefix(7).enumerated()), id: \.offset) { indice, fila in
                                CirculoIcono(simbolo: iconoDeCategoria(clave: fila.categoria, icono: fila.categoriaIcono),
                                             color: colorDeCategoria(hex: fila.categoriaColor, clave: fila.categoria), tamano: 30)
                                    .offset(x: CGFloat(indice) * 24)
                            }
                        }
                        .frame(width: 24 * CGFloat(min(7, filasConTope.count) - 1) + 30, height: 30, alignment: .leading)
                        if filasConTope.count > 7 {
                            Text("+\(filasConTope.count - 7)")
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .padding(.leading, 8)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private var tarjetaMeta: some View {
        let meta = datos.metaAhorro
        return KipCard {
            HStack(spacing: 12) {
                CirculoIcono(simbolo: "banknote.fill", color: KipColor.gradientEnd, tamano: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(meta.hayMeta ? "Meta: \(meta.nombre ?? "")" : "Meta de ahorro")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text(meta.hayMeta ? "Ahorro proyectado: \(meta.proyectadoTexto ?? "")" : "Sin una meta, lo que queda no tiene destino.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                Spacer(minLength: 4)
                if meta.hayMeta {
                    Text(meta.proyectadoTexto ?? "")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                } else {
                    Button("Crear") { alCrearMeta() }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
            }
        }
    }
}

// MARK: - Hojas

/// Una fila de las hojas de opciones: texto y chevron, como la Android.
struct FilaOpcionHoja: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var rojo = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                Text(texto)
                    .font(.manrope(16, weight: .semibold))
                    .foregroundStyle(rojo ? Color.red : KipColor.text(scheme))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HojaOpcionesPresupuesto: View {
    @Environment(\.colorScheme) private var scheme
    var alAdministrar: () -> Void = {}
    var alAgregar: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Elige una opción")
                .font(.manrope(20, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            FilaOpcionHoja(texto: "Administrar presupuesto", accion: alAdministrar)
            FilaOpcionHoja(texto: "Agregar presupuesto por categoría", accion: alAgregar)
            Spacer()
        }
        .background(KipColor.bg(scheme))
        .presentationDetents([.medium])
    }
}

struct HojaOpcionesAdministrar: View {
    @Environment(\.colorScheme) private var scheme
    var alAgregar: () -> Void = {}
    var alFAQ: () -> Void = {}
    var alReiniciar: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Elige una opción")
                .font(.manrope(20, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
            FilaOpcionHoja(texto: "Agregar presupuesto por categoría", accion: alAgregar)
            FilaOpcionHoja(texto: "Preguntas frecuentes", accion: alFAQ)
            FilaOpcionHoja(texto: "Empezar de nuevo", rojo: true, accion: alReiniciar)
            Spacer()
        }
        .background(KipColor.bg(scheme))
        .presentationDetents([.medium])
    }
}

struct HojaAgregarPresupuesto: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PresupuestoModelo
    @State private var busqueda = ""
    @State private var tope: TopeEditable? = nil
    @State private var hojaCrear = false
    @State private var pendienteTrasCrear: TopeEditable? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("Agregar presupuesto por categoría")
                    .font(.manrope(20, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Button { hojaCrear = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Crear categoría nueva")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                TextField("Buscar categorías", text: $busqueda)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 12)
            if let datos = modelo.datos {
                lista(datos)
            } else {
                ProgressView().tint(KipColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
            Spacer()
        }
        .background(KipColor.bg(scheme))
        .onChange(of: modelo.guardadoTick) { _ in cerrar() }
        .sheet(item: $tope) { elegido in
            HojaEditarTope(modelo: modelo, tope: elegido)
        }
        .sheet(isPresented: $hojaCrear, onDismiss: {
            // Al cerrarse la hoja de crear, se abre la de edicion del
            // tope de la categoria recien creada.
            if let pendiente = pendienteTrasCrear {
                tope = pendiente
                pendienteTrasCrear = nil
            }
        }) {
            HojaCrearCategoria(modelo: modelo) { creado in
                pendienteTrasCrear = creado
            }
        }
    }

    private func lista(_ datos: PresupuestoPantalla) -> some View {
        let conTope = Set(datos.filas.filter { $0.limite != nil }.map { $0.categoria })
        var disponibles = datos.categoriasDisponibles.filter { !conTope.contains($0.clave) }
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        if !texto.isEmpty {
            disponibles = disponibles.filter { $0.etiqueta.localizedCaseInsensitiveContains(texto) }
        }
        return contenidoLista(datos, disponibles: disponibles, texto: texto)
    }

    @ViewBuilder
    private func contenidoLista(_ datos: PresupuestoPantalla, disponibles: [CategoriaDisponible], texto: String) -> some View {
        if disponibles.isEmpty {
            Text(texto.isEmpty
                 ? "Ya tienes presupuesto en todas las categorías."
                 : "Ninguna categoría coincide con «\(texto)».")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.horizontal, 20)
                .padding(.top, 24)
        } else {
            // Alto fijo de la lista, como la Android (340dp).
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(disponibles) { disponible in
                        Button { tope = topeEditable(desdeDisponible: disponible) } label: {
                            HStack(spacing: 12) {
                                CirculoIcono(simbolo: iconoDeCategoria(clave: disponible.clave, icono: disponible.icono),
                                             color: colorDeCategoria(hex: disponible.color, clave: disponible.clave), tamano: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(disponible.etiqueta)
                                        .font(.manrope(16, weight: .bold))
                                        .foregroundStyle(KipColor.text(scheme))
                                        .lineLimit(1)
                                    Text("Promedio \(disponible.promedioTexto)")
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(height: 340)
            .padding(.top, 8)
        }
    }
}

/// El monto grande compartido por las hojas de tope e ingreso: botones
/// −/+ con paso fijo y piso 0, prefijo "$" y teclado decimal.
struct MontoGrande: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var texto: String
    let paso: Double
    var alCambiar: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Button("−") { ajustar(-paso) }
                .font(.manrope(28, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(width: 48, height: 48)
            HStack(spacing: 1) {
                Text("$")
                    .font(.manrope(26, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                TextField("0", text: $texto)
                    .keyboardType(.decimalPad)
                    .font(.manrope(26, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                    .multilineTextAlignment(.center)
                    .frame(width: 150)
                    .onChange(of: texto) { _ in alCambiar() }
            }
            Button("+") { ajustar(paso) }
                .font(.manrope(28, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func ajustar(_ delta: Double) {
        let actual = montoDesdeTexto(texto) ?? 0
        texto = numeroSinCeros(max(0, actual + delta))
    }
}

struct HojaEditarTope: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PresupuestoModelo
    let tope: TopeEditable
    @State private var montoTexto: String
    @State private var confirmarBorrado = false

    init(modelo: PresupuestoModelo, tope: TopeEditable) {
        self.modelo = modelo
        self.tope = tope
        _montoTexto = State(initialValue: tope.limite.map { numeroSinCeros($0) } ?? "")
    }

    private var monto: Double? { montoDesdeTexto(montoTexto) }
    private var puedeGuardar: Bool {
        guard let monto = monto else { return false }
        return monto >= 0 && !modelo.accionEnCurso
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    CirculoIcono(simbolo: iconoDeCategoria(clave: tope.clave, icono: tope.icono),
                                 color: colorDeCategoria(hex: tope.color, clave: tope.clave), tamano: 34)
                    Text(tope.etiqueta)
                        .font(.manrope(20, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .frame(maxWidth: .infinity)
                MontoGrande(texto: $montoTexto, paso: 5) { modelo.errorAccion = nil }
                if let datos = modelo.datos {
                    Divider().background(KipColor.border(scheme))
                    HStack {
                        columna(titulo: "Servicios", valor: datos.servicios.esperadoTexto)
                        columna(titulo: "Gastos", valor: datos.plan.totalAsignadoTexto)
                        columna(titulo: "Te queda", valor: datos.plan.quedaParaAhorroTexto)
                    }
                }
                if tope.promedio > 0 {
                    HStack(alignment: .top) {
                        Text("Promedio de los últimos 6 meses: \(tope.promedioTexto) al mes")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Spacer()
                        Button("Usar el promedio") {
                            montoTexto = numeroSinCeros(tope.promedio)
                            modelo.errorAccion = nil
                        }
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                    }
                }
                if !tope.historial.isEmpty && tope.historial.contains(where: { $0.gastado > 0 }) {
                    barrasHistorial
                }
                if let error = modelo.errorAccion {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                BotonPrimario(texto: modelo.accionEnCurso ? "Guardando…" : "Guardar",
                              cargando: modelo.accionEnCurso) {
                    if let monto = monto {
                        Task { await modelo.guardarTope(clave: tope.clave, limite: monto) }
                    }
                }
                .disabled(!puedeGuardar)
                if let idPresupuesto = tope.idPresupuesto {
                    Button {
                        if confirmarBorrado {
                            Task { await modelo.quitarTope(id: idPresupuesto) }
                        } else {
                            confirmarBorrado = true
                        }
                    } label: {
                        Text(confirmarBorrado ? "Toca de nuevo para borrar el presupuesto" : "Borrar presupuesto")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                    .disabled(modelo.accionEnCurso)
                }
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(KipColor.bg(scheme))
        .onAppear { confirmarBorrado = false }
        .onChange(of: modelo.guardadoTick) { _ in cerrar() }
    }

    private func columna(titulo: String, valor: String) -> some View {
        VStack(spacing: 2) {
            Text(titulo)
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(valor)
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var barrasHistorial: some View {
        let maximo = max(tope.historial.map { $0.gastado }.max() ?? 0, 0.01)
        return HStack(alignment: .bottom, spacing: 16) {
            ForEach(Array(tope.historial.enumerated()), id: \.offset) { indice, punto in
                VStack(spacing: 4) {
                    UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0, topTrailingRadius: 6)
                        .fill(indice == tope.historial.count - 1 ? KipColor.accent : KipColor.elevated(scheme))
                        .frame(width: 52, height: 8 + 40 * CGFloat(punto.gastado / maximo))
                    Text(punto.etiqueta)
                        .font(.manrope(12, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Text(dinero(punto.gastado))
                        .font(.manrope(12))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct HojaEditarIngreso: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PresupuestoModelo
    @State private var montoTexto: String

    init(modelo: PresupuestoModelo) {
        self.modelo = modelo
        // Precarga el ingreso GUARDADO (puede ser null: campo vacio),
        // nunca el efectivo sugerido.
        _montoTexto = State(initialValue: modelo.datos?.plan.ingresoEsperado.map { numeroSinCeros($0) } ?? "")
    }

    private var monto: Double? { montoDesdeTexto(montoTexto) }
    private var puedeGuardar: Bool {
        guard let monto = monto else { return false }
        return monto >= 0 && !modelo.accionEnCurso
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ingreso que esperas este mes")
                    .font(.manrope(20, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("El mes pasado entró \(modelo.datos?.plan.ingresoMesPasadoTexto ?? ""). De este número sale la resta de tu plan.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                MontoGrande(texto: $montoTexto, paso: 50) { modelo.errorAccion = nil }
                if let error = modelo.errorAccion {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                }
                BotonPrimario(texto: modelo.accionEnCurso ? "Guardando…" : "Guardar",
                              cargando: modelo.accionEnCurso) {
                    if let monto = monto {
                        Task { await modelo.guardarIngreso(monto) }
                    }
                }
                .disabled(!puedeGuardar)
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(KipColor.bg(scheme))
        .onChange(of: modelo.guardadoTick) { _ in cerrar() }
    }
}

struct HojaCrearCategoria: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PresupuestoModelo
    var alCreada: (TopeEditable) -> Void = { _ in }
    @State private var nombre = ""
    @State private var colorHex = "#2FA36B"
    @State private var icono = "etiqueta"

    /// La paleta de la casa (KipPasteles) como texto #RRGGBB: el color
    /// elegido se guarda como texto, no como objeto Color.
    private let colores: [String] = ["#2FA36B", "#3E7CB1", "#D97B29", "#7C5CBF", "#D45D8A",
                                     "#2A9D8F", "#C08A00", "#5B6ABF", "#9A6B4F", "#C94F4F"]
    /// La biblioteca de 60 iconos de la casa (las claves de iconoPorNombre).
    private let iconos: [String] = [
        "etiqueta", "comida", "carro", "casa", "salud", "gasolina", "restaurante", "supermercado",
        "compras", "banco", "entretenimiento", "viaje", "herramienta", "tijeras", "engrane", "edificio",
        "recibo", "cafe", "hamburguesa", "alcancia", "gimnasio", "camiseta", "laptop", "audifonos",
        "control", "planta", "pastilla", "estetoscopio", "pin", "wifi", "camara_seguridad", "bebe",
        "gato", "pez", "luna", "paraguas", "camion", "mapa", "diamante", "camara",
        "avion", "maleta", "sombrero", "papas", "barco", "huella", "libro", "regalo",
        "corazon", "porcentaje", "balanza", "escudo", "maletin", "familia", "telefono", "nube",
        "moneda", "musica", "tienda", "estrella",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nueva categoría")
                    .font(.manrope(20, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                CampoKip(etiqueta: "Nombre", texto: $nombre)
                Text("COLOR")
                    .font(.manrope(12, weight: .bold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(colores, id: \.self) { hex in
                        Button { colorHex = hex } label: {
                            Circle()
                                .fill(Color(hexCadena: hex))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(KipColor.text(scheme), lineWidth: colorHex == hex ? 2.5 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("ICONO")
                    .font(.manrope(12, weight: .bold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(iconos, id: \.self) { nombreIcono in
                        Button { icono = nombreIcono } label: {
                            Image(systemName: iconoPorNombre(nombreIcono))
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(icono == nombreIcono ? KipColor.onAccent : KipColor.text(scheme))
                                .frame(width: 44, height: 44)
                                .background(icono == nombreIcono ? KipColor.accent : KipColor.elevated(scheme))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                if let error = modelo.errorAccion {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                }
                BotonPrimario(texto: modelo.accionEnCurso ? "Creando…" : "Crear categoría",
                              cargando: modelo.accionEnCurso) {
                    crear()
                }
                .disabled(nombre.trimmingCharacters(in: .whitespaces).isEmpty)
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
        }
        .background(KipColor.bg(scheme))
    }

    private func crear() {
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        if nombreLimpio.isEmpty { return }
        Task {
            // Nace siempre como gasto (sin selector de tipo), con el
            // metodo P6 que ya usa Ajustes.
            if let tope = await modelo.crearCategoria(nombre: nombreLimpio, color: colorHex, icono: icono) {
                alCreada(tope)
                cerrar()
            }
        }
    }
}
