import SwiftUI

// La pantalla Metas (MetasScreen.kt de la Android): metas de ahorro
// con lista, detalle con aportes y retiros, el asistente guiado de 5
// pasos para crear y el formulario clasico para editar. Todo el
// calculo de ritmo lo hace el servidor: la app pinta frase, textos y
// porcentaje tal cual llegan.

@MainActor
final class MetasModelo: ObservableObject {
    @Published var datos: MetasDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var ocupada = false
    @Published var errorAccion: String? = nil
    @Published var accionesTerminadas = 0

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            datos = try await Api.metas()
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

    func crear(cuerpo: [String: Any]) async {
        await accion { _ = try await Api.crearMeta(cuerpo: cuerpo) }
    }

    func actualizar(id: Int, cuerpo: [String: Any]) async {
        await accion { _ = try await Api.editarMeta(id: id, cuerpo: cuerpo) }
    }

    func eliminar(id: Int) async {
        await accion { _ = try await Api.eliminarMeta(id: id) }
    }

    /// Archivar es un toggle del servidor, sin cuerpo ni estado
    /// deseado: la respuesta se descarta y se recarga el GET.
    func archivar(id: Int) async {
        await accion { _ = try await Api.archivarMeta(id: id) }
    }

    func aportar(id: Int, cuerpo: [String: Any]) async {
        await accion { _ = try await Api.aportarMeta(id: id, cuerpo: cuerpo) }
    }

    /// Toda accion descarta la respuesta y recarga el GET completo;
    /// al terminar sube accionesTerminadas para que la vista vuelva
    /// a la Lista si estaba en el asistente o en el formulario.
    private func accion(_ operacion: () async throws -> Void) async {
        if ocupada { return }
        ocupada = true
        errorAccion = nil
        do {
            try await operacion()
            datos = try await Api.metas()
            ocupada = false
            accionesTerminadas += 1
        } catch let e as ApiError {
            ocupada = false
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorAccion = e.errorDescription ?? "Algo salió mal."
        } catch {
            ocupada = false
            errorAccion = "Algo salió mal."
        }
    }
}

/// Las vistas internas de la pantalla (Lista / Detalle / asistente /
/// formulario de edicion), como la maquina de estados de la Android.
enum VistaMeta: Equatable {
    case lista
    case detalle(Int)
    case asistente
    case editar(Int)
}

/// La fecha de hoy del telefono en yyyy-MM-dd (la que manda el aporte).
func hoyISO() -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}

struct MetasView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo = MetasModelo()
    @State private var vista: VistaMeta = .lista

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    if vista == .lista { cerrar() } else { vista = .lista }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text(tituloCabecera)
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            if let error = modelo.errorAccion {
                Text(error)
                    .font(.manrope(15))
                    .foregroundStyle(Color.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }
            EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
                if let datos = modelo.datos {
                    contenido(datos)
                }
            } reintentar: {
                Task { await modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme))
        .task {
            if modelo.datos == nil { await modelo.cargar() }
        }
        .onChange(of: modelo.accionesTerminadas) { _ in
            switch vista {
            case .asistente, .editar:
                vista = .lista
            case .detalle(let id):
                if let datos = modelo.datos,
                   !(datos.metas + datos.archivadas).contains(where: { $0.id == id }) {
                    vista = .lista
                }
            case .lista:
                break
            }
        }
    }

    private var tituloCabecera: String {
        switch vista {
        case .lista: return "Metas de ahorro"
        case .detalle(let id): return metaActual(id)?.nombre ?? "Metas de ahorro"
        case .asistente: return "Nueva meta"
        case .editar: return "Editar meta"
        }
    }

    private func metaActual(_ id: Int) -> MetaDto? {
        guard let datos = modelo.datos else { return nil }
        return (datos.metas + datos.archivadas).first { $0.id == id }
    }

    @ViewBuilder
    private func contenido(_ datos: MetasDto) -> some View {
        switch vista {
        case .lista:
            ListaMetasView(datos: datos,
                           alNueva: { modelo.errorAccion = nil; vista = .asistente },
                           alAbrir: { vista = .detalle($0) },
                           alRecargar: { await modelo.cargar() })
        case .detalle(let id):
            if let meta = metaActual(id) {
                DetalleMetaView(modelo: modelo, meta: meta, datos: datos,
                                alEditar: { vista = .editar(id) })
            } else {
                ListaMetasView(datos: datos,
                               alNueva: { modelo.errorAccion = nil; vista = .asistente },
                               alAbrir: { vista = .detalle($0) },
                               alRecargar: { await modelo.cargar() })
            }
        case .asistente:
            AsistenteMetaView(modelo: modelo)
        case .editar(let id):
            if let meta = metaActual(id) {
                FormularioMetaView(modelo: modelo, meta: meta, cuentas: datos.cuentas)
            }
        }
    }
}

// MARK: - Lista

struct ListaMetasView: View {
    @Environment(\.colorScheme) private var scheme
    let datos: MetasDto
    var alNueva: () -> Void = {}
    var alAbrir: (Int) -> Void = { _ in }
    var alRecargar: () async -> Void = {}

    var body: some View {
        if datos.metas.isEmpty && datos.archivadas.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                ZStack {
                    Circle().fill(KipColor.gradientEnd)
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }
                .frame(width: 76, height: 76)
                Text("Todavía no tienes metas. Crea la primera: un fondo de emergencia, un viaje, lo que quieras apartar poco a poco.")
                    .font(.manrope(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.horizontal, 32)
                BotonPrimario(texto: "Nueva meta") { alNueva() }
                    .frame(maxWidth: 260)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    BotonPrimario(texto: "Nueva meta") { alNueva() }
                    ForEach(datos.metas) { meta in
                        TarjetaMeta(meta: meta) { alAbrir(meta.id) }
                    }
                    if !datos.archivadas.isEmpty {
                        Text("Archivadas")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.top, 6)
                        ForEach(datos.archivadas) { meta in
                            TarjetaMeta(meta: meta) { alAbrir(meta.id) }
                        }
                    }
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .refreshable { await alRecargar() }
        }
    }
}

struct TarjetaMeta: View {
    @Environment(\.colorScheme) private var scheme
    let meta: MetaDto
    var alTocar: () -> Void = {}

    var body: some View {
        Button(action: alTocar) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(meta.nombre)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .lineLimit(1)
                    Spacer()
                    Text("\(porcentajeLegible(meta.porcentaje))%")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                BarraMeta(fraccion: meta.porcentaje / 100)
                Text("\(meta.ahorradoTexto) de \(meta.objetivoTexto)")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
                if !meta.frase.isEmpty {
                    Text(meta.frase)
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// La barra de avance de la tarjeta: pista gris y relleno con el
/// degradado de la marca, de 8 de alto.
struct BarraMeta: View {
    let fraccion: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(max(fraccion, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Detalle

struct DetalleMetaView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: MetasModelo
    let meta: MetaDto
    let datos: MetasDto
    var alEditar: () -> Void = {}
    @State private var esRetiro = false
    @State private var montoTexto = ""
    @State private var notaTexto = ""
    @State private var confirmandoEliminar = false

    private var montoAporte: Double? {
        let limpio = montoTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty { return nil }
        return Double(limpio)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                BarraProgreso(fraccion: meta.porcentaje / 100, color: KipColor.accent)
                    .padding(.top, 6)
                Text("\(meta.ahorradoTexto) de \(meta.objetivoTexto) (\(porcentajeLegible(meta.porcentaje))%)")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                if !meta.completada {
                    Text("Te faltan \(meta.faltanteTexto).")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if let fechaTexto = meta.fechaObjetivoTexto {
                    Text("Fecha objetivo: \(fechaTexto)")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                if let apartadoTexto = meta.apartadoMensualTexto, !meta.completada {
                    Text("Aparta \(apartadoTexto) al mes para llegar.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                if let cuentaNombre = meta.cuentaNombre {
                    Text("Lo guardas en: \(cuentaNombre)")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                if !meta.frase.isEmpty {
                    Text(meta.frase)
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                bloqueMovimiento
                if !meta.movimientos.isEmpty {
                    bloqueRecientes
                }
                VStack(spacing: 10) {
                    BotonContorno(texto: "Editar la meta") { alEditar() }
                    BotonContorno(texto: meta.archivada ? "Desarchivar" : "Archivar") {
                        Task { await modelo.archivar(id: meta.id) }
                    }
                    .disabled(modelo.ocupada)
                    .opacity(modelo.ocupada ? 0.55 : 1)
                    botonEliminar
                }
                .padding(.top, 10)
                Color.clear.frame(height: 110)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .onChange(of: meta.id) { _ in confirmandoEliminar = false }
    }

    private var bloqueMovimiento: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registrar un movimiento")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.top, 8)
            HStack(spacing: 8) {
                chipSigno(titulo: "Apartar", elegido: !esRetiro) { esRetiro = false }
                chipSigno(titulo: "Retirar", elegido: esRetiro) { esRetiro = true }
                Spacer()
            }
            CampoKip(etiqueta: "Monto", texto: $montoTexto)
            CampoKip(etiqueta: "Nota (opcional)", texto: $notaTexto)
            BotonPrimario(texto: esRetiro ? "Registrar el retiro" : "Registrar la aportación") {
                registrar()
            }
            .disabled(modelo.ocupada || (montoAporte ?? 0) <= 0)
            .opacity(modelo.ocupada || (montoAporte ?? 0) <= 0 ? 0.55 : 1)
        }
    }

    private func chipSigno(titulo: String, elegido: Bool, accion: @escaping () -> Void) -> some View {
        Button(titulo, action: accion)
            .font(.manrope(14, weight: .bold))
            .foregroundStyle(elegido ? KipColor.onAccent : KipColor.text(scheme))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(elegido ? KipColor.accent : KipColor.card(scheme))
            .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegido ? 0 : 1))
            .clipShape(Capsule())
    }

    /// El signo lo pone el chip y la fecha es hoy en el telefono.
    /// Los campos se limpian en el momento del toque, salga bien o
    /// mal el registro, como en la Android.
    private func registrar() {
        guard let monto = montoAporte, monto > 0 else { return }
        let firmado = esRetiro ? -monto : monto
        let nota = notaTexto.trimmingCharacters(in: .whitespaces)
        let cuerpo: [String: Any] = [
            "monto": firmado,
            "fecha": hoyISO(),
            "nota": nota.isEmpty ? NSNull() : nota,
        ]
        montoTexto = ""
        notaTexto = ""
        Task { await modelo.aportar(id: meta.id, cuerpo: cuerpo) }
    }

    private var bloqueRecientes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movimientos recientes")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.top, 8)
            ForEach(meta.movimientos) { mov in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fechaLegible(mov.fecha))
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.text(scheme))
                        if let nota = mov.nota, !nota.isEmpty {
                            Text(nota)
                                .font(.manrope(13))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                    Spacer()
                    if mov.monto >= 0 {
                        Text("+ \(dinero(mov.monto))")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.accent)
                    } else {
                        Text("\u{2212} \(dinero(abs(mov.monto)))")
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Eliminar pide dos toques en el mismo boton, sin dialogo.
    private var botonEliminar: some View {
        Button {
            if confirmandoEliminar {
                Task { await modelo.eliminar(id: meta.id) }
            } else {
                confirmandoEliminar = true
            }
        } label: {
            Text(confirmandoEliminar ? "Toca de nuevo para eliminar" : "Eliminar la meta")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(Capsule().stroke(Color.red, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(modelo.ocupada)
        .opacity(modelo.ocupada ? 0.55 : 1)
    }
}

// MARK: - Asistente guiado (crear)

/// El tipo del paso 1 del asistente: su clave y su nombre sugerido
/// son locales; al servidor solo viaja el nombre.
struct TipoMeta {
    let clave: String
    let etiqueta: String
    let sugerido: String
    let icono: String
}

let TIPOS_META: [TipoMeta] = [
    TipoMeta(clave: "emergencia", etiqueta: "Fondo de emergencia", sugerido: "Fondo de emergencia", icono: "cross.case.fill"),
    TipoMeta(clave: "carro", etiqueta: "Carro", sugerido: "Carro", icono: "car.fill"),
    TipoMeta(clave: "casa", etiqueta: "Casa", sugerido: "Casa", icono: "house.fill"),
    TipoMeta(clave: "vacaciones", etiqueta: "Vacaciones", sugerido: "Vacaciones", icono: "airplane"),
    TipoMeta(clave: "jubilacion", etiqueta: "Jubilación", sugerido: "Jubilación", icono: "banknote.fill"),
    TipoMeta(clave: "otra", etiqueta: "Otra", sugerido: "", icono: "square.grid.2x2.fill"),
]

struct AsistenteMetaView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: MetasModelo
    @State private var paso = 0
    @State private var tipoElegido: TipoMeta? = nil
    @State private var nombre = ""
    @State private var objetivoTexto = ""
    @State private var inicialTexto = ""
    @State private var aporteTexto = ""

    private let iconosPaso = ["flag.fill", "square.grid.2x2.fill", "pencil", "dollarsign.circle.fill", "calendar"]

    private var objetivo: Double? { parseMontoConComa(objetivoTexto) }
    private var inicial: Double { parseMontoConComa(inicialTexto) ?? 0 }

    /// La estimacion del paso 4: meses = ceil(faltante / aporte),
    /// minimo 1; sin aporte no hay estimacion.
    private var mesesEstimados: Int? {
        guard let objetivo = objetivo, objetivo > 0 else { return nil }
        let faltante = objetivo - inicial
        if faltante <= 0 { return 0 }
        if let aporte = parseMontoConComa(aporteTexto), aporte > 0 {
            return max(1, Int(ceil(faltante / aporte)))
        }
        return nil
    }

    private var fechaEstimada: Date? {
        guard let meses = mesesEstimados, meses > 0 else { return nil }
        return Calendar.current.date(byAdding: .month, value: meses, to: Date())
    }

    private var pasoValido: Bool {
        switch paso {
        case 0: return true
        case 1: return tipoElegido != nil
        case 2: return !nombre.isEmpty
        case 3: return (objetivo ?? 0) > 0
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Paso \(paso + 1) de 5")
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    BarraProgreso(fraccion: Double(paso + 1) / 5, color: KipColor.accent)
                    KipCard {
                        VStack(alignment: .leading, spacing: 14) {
                            ZStack {
                                Circle().fill(KipColor.gradientEnd)
                                Image(systemName: iconosPaso[paso])
                                    .font(.system(size: 38))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 84, height: 84)
                            contenidoPaso
                        }
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            HStack(spacing: 12) {
                if paso > 0 {
                    Button("Atrás") { paso -= 1 }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
                Spacer()
                BotonPrimario(texto: textoBotonPrincipal, cargando: modelo.ocupada && paso == 4) {
                    if paso < 4 { paso += 1 } else { crear() }
                }
                .frame(maxWidth: 220)
                .disabled(!pasoValido || modelo.ocupada)
                .opacity(!pasoValido || modelo.ocupada ? 0.55 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var textoBotonPrincipal: String {
        switch paso {
        case 0: return "Empezar"
        case 4: return modelo.ocupada ? "Creando…" : "Crear mi meta"
        default: return "Continuar"
        }
    }

    @ViewBuilder
    private var contenidoPaso: some View {
        switch paso {
        case 0:
            VStack(alignment: .leading, spacing: 10) {
                Text("Vamos a crear tu meta")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Una meta te ayuda a apartar dinero con un propósito: un fondo para emergencias, un carro, unas vacaciones.")
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Ojo: Kipwallet no mueve tu dinero. La meta es tu guía: tú apartas el dinero en tu banco y aquí llevas tu avance.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        case 1:
            VStack(alignment: .leading, spacing: 12) {
                Text("¿Para qué es la meta?")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(TIPOS_META, id: \.clave) { tipo in
                        tarjetaTipo(tipo)
                    }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: 12) {
                Text("¿Cómo se llama tu meta?")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                CampoKip(etiqueta: "Nombre de la meta", texto: $nombre)
            }
        case 3:
            VStack(alignment: .leading, spacing: 12) {
                Text("¿Cuánto quieres juntar?")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                CampoMontoKip(etiqueta: "Monto de la meta", texto: $objetivoTexto)
                CampoMontoKip(etiqueta: "¿Ya tienes algo apartado? (opcional)", texto: $inicialTexto)
            }
        default:
            VStack(alignment: .leading, spacing: 12) {
                Text("¿Cuánto apartarías cada mes?")
                    .font(.manrope(24, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                CampoMontoKip(etiqueta: "Aporte por mes (opcional)", texto: $aporteTexto)
                textoEstimacion
            }
        }
    }

    private func tarjetaTipo(_ tipo: TipoMeta) -> some View {
        let elegido = tipoElegido?.clave == tipo.clave
        return Button { elegirTipo(tipo) } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(KipColor.gradientEnd)
                    Image(systemName: tipo.icono)
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                Text(tipo.etiqueta)
                    .font(.manrope(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KipColor.text(scheme))
                if elegido {
                    Text("Elegida")
                        .font(.manrope(12, weight: .bold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(elegido ? KipColor.accent : KipColor.border(scheme), lineWidth: elegido ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    /// El nombre se sugiere al elegir tipo: si el campo esta vacio o
    /// trae la sugerencia del tipo anterior, se reemplaza; un nombre
    /// propio del usuario se respeta.
    private func elegirTipo(_ tipo: TipoMeta) {
        let sugeridoAnterior = tipoElegido?.sugerido
        if nombre.isEmpty || nombre == sugeridoAnterior {
            nombre = tipo.sugerido
        }
        tipoElegido = tipo
    }

    @ViewBuilder
    private var textoEstimacion: some View {
        if let meses = mesesEstimados {
            if meses == 0 {
                Text("Con lo que ya tienes apartado, tu meta de \(dinero(objetivo ?? 0)) ya está cubierta.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
            } else if let fecha = fechaEstimada {
                Text("A ese ritmo la alcanzas el \(fechaLegible(isoDeFecha(fecha))) (en \(meses) meses). Esa será la fecha objetivo de tu meta.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
            }
        } else {
            Text("Sin un aporte por mes no puedo estimar la fecha. Puedes crear la meta sin fecha y ajustarla después.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
        }
    }

    /// El asistente no manda tipo ni cuenta: la fecha objetivo es la
    /// estimada por el aporte mensual (o ninguna).
    private func crear() {
        guard let objetivo = objetivo else { return }
        modelo.errorAccion = nil
        let cuerpo: [String: Any] = [
            "nombre": nombre.trimmingCharacters(in: .whitespaces),
            "monto_objetivo": objetivo,
            "monto_inicial": inicial,
            "fecha_objetivo": fechaEstimada.map { isoDeFecha($0) } ?? NSNull(),
        ]
        Task { await modelo.crear(cuerpo: cuerpo) }
    }
}

// MARK: - Formulario clasico (editar)

struct FormularioMetaView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: MetasModelo
    let meta: MetaDto
    let cuentas: [CuentaSimpleDto]
    @State private var nombre: String
    @State private var objetivoTexto: String
    @State private var fechaTexto: String
    @State private var cuentaId: Int?

    init(modelo: MetasModelo, meta: MetaDto, cuentas: [CuentaSimpleDto]) {
        self.modelo = modelo
        self.meta = meta
        self.cuentas = cuentas
        _nombre = State(initialValue: meta.nombre)
        _objetivoTexto = State(initialValue: meta.objetivo > 0 ? String(meta.objetivo) : "")
        _fechaTexto = State(initialValue: meta.fechaObjetivo ?? "")
        _cuentaId = State(initialValue: meta.cuentaId)
    }

    private var objetivo: Double? {
        let limpio = objetivoTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty { return nil }
        return Double(limpio)
    }

    private var fechaValida: Bool {
        let limpio = fechaTexto.trimmingCharacters(in: .whitespaces)
        if limpio.isEmpty { return true }
        return limpio.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    private var valido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && (objetivo ?? 0) > 0 && fechaValida
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CampoKip(etiqueta: "Nombre de la meta", texto: $nombre)
                    CampoKip(etiqueta: "¿Cuánto quieres juntar?", texto: $objetivoTexto)
                    CampoKip(etiqueta: "Fecha objetivo (opcional)", texto: $fechaTexto)
                    if !cuentas.isEmpty {
                        Text("¿Dónde lo guardas?")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.top, 4)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                            chipCuenta(titulo: "Sin cuenta", id: nil)
                            ForEach(cuentas) { cuenta in
                                chipCuenta(titulo: cuenta.nombre, id: cuenta.id)
                            }
                        }
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            BotonPrimario(texto: "Guardar los cambios", cargando: modelo.ocupada) {
                guardar()
            }
            .disabled(!valido || modelo.ocupada)
            .opacity(!valido || modelo.ocupada ? 0.55 : 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chipCuenta(titulo: String, id: Int?) -> some View {
        let elegido = cuentaId == id
        return Button(titulo) { cuentaId = id }
            .font(.manrope(14, weight: .bold))
            .foregroundStyle(elegido ? KipColor.onAccent : KipColor.text(scheme))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(elegido ? KipColor.accent : KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: elegido ? 0 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// La cuenta viaja como `financial_account_id` y el monto
    /// inicial va intacto (el campo no se muestra en edicion).
    private func guardar() {
        guard let objetivo = objetivo else { return }
        modelo.errorAccion = nil
        let fecha = fechaTexto.trimmingCharacters(in: .whitespaces)
        let cuerpo: [String: Any] = [
            "nombre": nombre.trimmingCharacters(in: .whitespaces),
            "monto_objetivo": objetivo,
            "monto_inicial": meta.montoInicial,
            "fecha_objetivo": fecha.isEmpty ? NSNull() : fecha,
            "financial_account_id": cuentaId ?? NSNull(),
        ]
        Task { await modelo.actualizar(id: meta.id, cuerpo: cuerpo) }
    }
}
