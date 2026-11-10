import SwiftUI

// La pantalla Patrimonio (PatrimonioScreen.kt de la Android): la foto
// de lo que tienes menos lo que debes, con sus tres pestanas
// (Resumen, Activos, Deudas), la grafica estimada por rango y los
// bienes registrados a mano. El servidor es la unica verdad: las
// mutaciones devuelven la foto completa y se adopta tal cual.

/// El parseo de montos de Patrimonio (y del asistente de Metas):
/// acepta la coma como separador decimal, como la Android.
func parseMontoConComa(_ texto: String) -> Double? {
    let limpio = texto.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
    if limpio.isEmpty { return nil }
    return Double(limpio)
}

/// Un campo de monto con prefijo $ y teclado decimal, con el estilo de
/// CampoKip (que no trae prefijo ni teclado decimal).
struct CampoMontoKip: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    @Binding var texto: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etiqueta)
                .font(.manrope(13, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            HStack(spacing: 4) {
                Text("$")
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                TextField("", text: $texto)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                    .keyboardType(.decimalPad)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

@MainActor
final class PatrimonioModelo: ObservableObject {
    @Published var datos: PatrimonioDto? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var rango = "3M"
    @Published var accionEnCurso = false
    @Published var errorAccion: String? = nil
    @Published var guardadoTick = 0

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            let r = try await Api.patrimonio(rango: rango)
            datos = r
            rango = r.rango
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

    func cambiarRango(_ nuevo: String) async {
        if nuevo == rango && datos != nil { return }
        rango = nuevo
        await cargar()
    }

    func agregar(kind: String, grupo: String, nombre: String, monto: Double) async {
        let cuerpo: [String: Any] = [
            "nombre": nombre,
            "kind": kind,
            "grupo": grupo,
            "monto": monto,
            "con_prestamo": grupo == "con_prestamo" && kind == "activo",
        ]
        await accion { try await Api.agregarBien(cuerpo: cuerpo) }
    }

    /// Al editar, kind, grupo y con_prestamo se conservan del bien
    /// original (la hoja de edicion no tiene selector de tipo).
    func editar(bien: BienManualDto, nombre: String, monto: Double) async {
        let cuerpo: [String: Any] = [
            "nombre": nombre,
            "kind": bien.kind,
            "grupo": bien.grupo ?? NSNull(),
            "monto": monto,
            "con_prestamo": bien.conPrestamo,
        ]
        await accion { try await Api.editarBien(id: bien.id, cuerpo: cuerpo) }
    }

    func eliminar(bien: BienManualDto) async {
        await accion { try await Api.borrarBien(id: bien.id) }
    }

    /// Toda mutacion adopta la foto completa que devuelve el servidor
    /// (con su rango, que vuelve a 3M) y avisa con guardadoTick para
    /// que la hoja abierta se cierre sola.
    private func accion(_ operacion: () async throws -> PatrimonioDto) async {
        if accionEnCurso { return }
        accionEnCurso = true
        errorAccion = nil
        do {
            let r = try await operacion()
            datos = r
            rango = r.rango
            accionEnCurso = false
            guardadoTick += 1
        } catch let e as ApiError {
            accionEnCurso = false
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorAccion = e.errorDescription ?? "No se pudo guardar. Intenta de nuevo."
        } catch {
            accionEnCurso = false
            errorAccion = "No se pudo guardar. Intenta de nuevo."
        }
    }
}

/// El tipo elegible de la rejilla de Agregar: la clave `grupo` que
/// viaja al servidor, su etiqueta y su icono.
struct TipoBien {
    let grupo: String
    let etiqueta: String
    let icono: String
}

let TIPOS_ACTIVO: [TipoBien] = [
    TipoBien(grupo: "efectivo", etiqueta: "Efectivo", icono: "dollarsign.circle.fill"),
    TipoBien(grupo: "inversiones", etiqueta: "Inversiones", icono: "chart.pie.fill"),
    TipoBien(grupo: "con_prestamo", etiqueta: "Activo con préstamo", icono: "house.fill"),
    TipoBien(grupo: "otros", etiqueta: "Otro activo", icono: "square.grid.2x2.fill"),
]

let TIPOS_PASIVO: [TipoBien] = [
    TipoBien(grupo: "tarjetas", etiqueta: "Tarjeta", icono: "creditcard.fill"),
    TipoBien(grupo: "largo_plazo", etiqueta: "Largo plazo", icono: "house.fill"),
    TipoBien(grupo: "con_respaldo", etiqueta: "Préstamo con respaldo", icono: "car.fill"),
    TipoBien(grupo: "otras", etiqueta: "Otra deuda", icono: "doc.text.fill"),
]

struct PatrimonioView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo = PatrimonioModelo()
    @State private var pestana = 0
    @State private var agregarKind: String? = nil
    @State private var editando: BienManualDto? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { cerrar() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text("Patrimonio")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            contenido
        }
        .background(KipColor.bg(scheme))
        .task {
            if modelo.datos == nil { await modelo.cargar() }
        }
        .sheet(isPresented: Binding(get: { agregarKind != nil }, set: { if !$0 { agregarKind = nil } })) {
            if let kind = agregarKind {
                HojaAgregarBien(modelo: modelo, kind: kind)
            }
        }
        .sheet(item: $editando) { bien in
            HojaEditarBien(modelo: modelo, bien: bien)
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if let datos = modelo.datos {
            if datos.sinDatos {
                estadoVacio
            } else {
                VStack(spacing: 0) {
                    barraPestanas
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            switch pestana {
                            case 1:
                                pestanaLado(datos, esActivos: true)
                            case 2:
                                pestanaLado(datos, esActivos: false)
                            default:
                                pestanaResumen(datos)
                            }
                            Color.clear.frame(height: 110)
                        }
                    }
                    .refreshable { await modelo.cargar() }
                }
            }
        } else if modelo.cargando {
            VStack { Spacer(); ProgressView().tint(KipColor.accent); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                Spacer()
                Text(modelo.errorTexto ?? "No se pudo cargar tu patrimonio.")
                    .font(.manrope(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KipColor.text(scheme))
                    .padding(.horizontal, 24)
                Button("Reintentar") { Task { await modelo.cargar() } }
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var barraPestanas: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Resumen", "Activos", "Deudas"].enumerated()), id: \.offset) { indice, titulo in
                Button { pestana = indice } label: {
                    VStack(spacing: 6) {
                        Text(titulo)
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(pestana == indice ? KipColor.text(scheme) : KipColor.textSecondary(scheme))
                        Rectangle()
                            .fill(pestana == indice ? KipColor.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .overlay(Divider().background(KipColor.border(scheme)), alignment: .bottom)
    }

    // MARK: - Estado vacio

    private var estadoVacio: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Aquí verás todo lo que tienes menos todo lo que debes.")
                .font(.manrope(22, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(KipColor.text(scheme))
            Text("Conecta tu banco desde el Panel o agrega un bien o una deuda a mano para empezar.")
                .font(.manrope(16))
                .multilineTextAlignment(.center)
                .foregroundStyle(KipColor.textSecondary(scheme))
            BotonPrimario(texto: "Agregar un bien a mano") { agregarKind = "activo" }
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Pestana Resumen

    private func pestanaResumen(_ datos: PatrimonioDto) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Patrimonio neto")
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(datos.netoTexto)
                .font(.manrope(32, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.top, 2)
            if let frase = fraseCambio(cambio: datos.cambio, cambioTexto: datos.cambioTexto,
                                       sube: "Tu patrimonio subió", baja: "Tu patrimonio bajó") {
                Text(frase)
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.top, 2)
            }
            GraficaPatrimonio(valores: datos.serie.map { $0.neto ?? 0 })
                .padding(.top, 14)
            SelectorRangosPatrimonio(modelo: modelo, datos: datos)
                .padding(.top, 10)
            Text("Gráfica estimada desde tus movimientos sincronizados; los bienes registrados a mano no entran en la gráfica.")
                .font(.manrope(13))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.top, 10)
            KipCard(padding: 0) {
                VStack(spacing: 0) {
                    filaResumen(icono: "wallet.pass.fill", color: KipPastel.verde, etiqueta: "Activos",
                                texto: datos.activosTexto) { pestana = 1 }
                    Divider().background(KipColor.border(scheme))
                    filaResumen(icono: "creditcard.fill", color: KipPastel.rojo, etiqueta: "Deudas",
                                texto: datos.deudasTexto) { pestana = 2 }
                }
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func filaResumen(icono: String, color: Color, etiqueta: String, texto: String,
                             accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack(spacing: 12) {
                CirculoIcono(simbolo: icono, color: color)
                Text(etiqueta)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Text(texto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pestanas Activos y Deudas

    private func pestanaLado(_ datos: PatrimonioDto, esActivos: Bool) -> some View {
        let grupos = esActivos ? datos.activosGrupos : datos.deudasGrupos
        return VStack(alignment: .leading, spacing: 0) {
            Text(esActivos ? "Activos" : "Deudas")
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Text(esActivos ? datos.activosTexto : datos.deudasTexto)
                .font(.manrope(32, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.top, 2)
            if let frase = fraseCambio(cambio: esActivos ? datos.cambioActivos : datos.cambioDeudas,
                                       cambioTexto: esActivos ? datos.cambioActivosTexto : datos.cambioDeudasTexto,
                                       sube: esActivos ? "Tus activos subieron" : "Tus deudas subieron",
                                       baja: esActivos ? "Tus activos bajaron" : "Tus deudas bajaron") {
                Text(frase)
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.top, 2)
            }
            GraficaPatrimonio(valores: (esActivos ? datos.serieActivos : datos.serieDeudas).map { $0.neto ?? 0 })
                .padding(.top, 14)
            SelectorRangosPatrimonio(modelo: modelo, datos: datos)
                .padding(.top, 10)
            ForEach(grupos) { grupo in
                tarjetaGrupo(grupo, datos: datos)
                    .padding(.top, 14)
            }
            BotonPrimario(texto: esActivos ? "Agregar activo" : "Agregar deuda") {
                agregarKind = esActivos ? "activo" : "pasivo"
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func tarjetaGrupo(_ grupo: PatrimonioGrupoDto, datos: PatrimonioDto) -> some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    Text(grupo.etiqueta)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(grupo.subtotalTexto)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("\(Int(grupo.pct))% del total")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
                .padding(16)
                Divider().background(KipColor.border(scheme))
                ForEach(Array(grupo.items.enumerated()), id: \.offset) { indice, item in
                    if indice > 0 { Divider().background(KipColor.border(scheme)) }
                    filaItem(item, datos: datos)
                }
            }
        }
    }

    @ViewBuilder
    private func filaItem(_ item: PatrimonioItemDto, datos: PatrimonioDto) -> some View {
        let bien = item.manualId.flatMap { id in datos.bienes.first { $0.id == id } }
        let contenido = HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.nombre)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                if let subtitulo = subtituloItem(item, datos: datos) {
                    Text(subtitulo)
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
            Spacer()
            Text(item.montoTexto)
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        if let bien = bien {
            Button { editando = bien } label: { contenido }
                .buttonStyle(.plain)
        } else {
            contenido
        }
    }

    /// El subtitulo de la fila: primero el `detalle` del servidor tal
    /// cual (los pasivos manuales muestran «Registrada a mano» sin la
    /// invitacion a editar); si no hay detalle y el item es manual,
    /// la invitacion a editar.
    private func subtituloItem(_ item: PatrimonioItemDto, datos: PatrimonioDto) -> String? {
        if let detalle = item.detalle, !detalle.isEmpty { return detalle }
        if item.manualId != nil { return "Registrado a mano · toca para editar" }
        return nil
    }

    /// La frase de cambio de cada pestana: la calcula el cliente con
    /// su propio dinero(); el texto del servidor solo condiciona.
    private func fraseCambio(cambio: Double?, cambioTexto: String?, sube: String, baja: String) -> String? {
        guard let cambio = cambio, cambioTexto != nil else { return nil }
        if cambio > 0 { return "\(sube) \(dinero(cambio)) en el periodo." }
        if cambio < 0 { return "\(baja) \(dinero(abs(cambio))) en el periodo." }
        return "Sin cambios en el periodo."
    }
}

// MARK: - Grafica y selector de rangos

/// La grafica de serie de Patrimonio: linea Accent de 2 con area al
/// 15 %, 140 de alto, sin ejes. Con menos de 2 puntos, el texto de
/// falta de historial.
struct GraficaPatrimonio: View {
    @Environment(\.colorScheme) private var scheme
    let valores: [Double]

    var body: some View {
        if valores.count < 2 {
            Text("Todavía no hay historial suficiente para la gráfica.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Canvas { contexto, tamano in
                let minimo = valores.min() ?? 0
                let maximoReal = valores.max() ?? 0
                let rango = (maximoReal - minimo) < 0.01 ? 1.0 : (maximoReal - minimo)
                let pasoX = tamano.width / CGFloat(valores.count - 1)
                func punto(_ i: Int) -> CGPoint {
                    let y = tamano.height - CGFloat((valores[i] - minimo) / rango) * (tamano.height - 8) - 4
                    return CGPoint(x: CGFloat(i) * pasoX, y: y)
                }
                var area = Path()
                area.move(to: CGPoint(x: 0, y: tamano.height))
                for i in valores.indices { area.addLine(to: punto(i)) }
                area.addLine(to: CGPoint(x: tamano.width, y: tamano.height))
                area.closeSubpath()
                contexto.fill(area, with: .color(KipColor.accent.opacity(0.15)))
                var linea = Path()
                for i in valores.indices {
                    if i == 0 { linea.move(to: punto(i)) } else { linea.addLine(to: punto(i)) }
                }
                contexto.stroke(linea, with: .color(KipColor.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 140)
        }
    }
}

struct SelectorRangosPatrimonio: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: PatrimonioModelo
    let datos: PatrimonioDto

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(datos.rangosDisponibles, id: \.self) { clave in
                    let elegida = datos.rango == clave
                    Button(clave == "todo" ? "Todo" : clave) {
                        Task { await modelo.cambiarRango(clave) }
                    }
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(elegida ? KipColor.accent : KipColor.card(scheme))
                    .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Hojas Agregar y Editar

/// La hoja de alta de un bien manual: rejilla 2×2 de tipos, nombre y
/// monto. Al guardar bien se cierra sola (guardadoTick del modelo).
struct HojaAgregarBien: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PatrimonioModelo
    let kind: String
    @State private var grupoElegido: String
    @State private var nombre = ""
    @State private var montoTexto = ""

    init(modelo: PatrimonioModelo, kind: String) {
        self.modelo = modelo
        self.kind = kind
        _grupoElegido = State(initialValue: (kind == "activo" ? TIPOS_ACTIVO : TIPOS_PASIVO).first?.grupo ?? "")
    }

    private var tipos: [TipoBien] { kind == "activo" ? TIPOS_ACTIVO : TIPOS_PASIVO }
    private var monto: Double? { parseMontoConComa(montoTexto) }
    private var valido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && (monto ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(kind == "activo" ? "Agregar activo" : "Agregar deuda")
                        .font(.manrope(22, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Elige el tipo y ponle nombre y monto. Queda registrado a mano: tú lo actualizas cuando cambie.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(tipos, id: \.grupo) { tipo in
                            mosaicoTipo(tipo)
                        }
                    }
                    .frame(height: 252)
                    CampoKip(etiqueta: "Nombre", texto: $nombre)
                    CampoMontoKip(etiqueta: kind == "activo" ? "Cuánto vale" : "Cuánto debes", texto: $montoTexto)
                    if let error = modelo.errorAccion {
                        Text(error)
                            .font(.manrope(14))
                            .foregroundStyle(Color.red)
                    }
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            BotonPrimario(texto: modelo.accionEnCurso ? "Guardando…" : "Guardar", cargando: modelo.accionEnCurso) {
                guardar()
            }
            .disabled(!valido || modelo.accionEnCurso)
            .opacity(!valido || modelo.accionEnCurso ? 0.55 : 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(KipColor.bg(scheme))
        .onAppear { modelo.errorAccion = nil }
        .onChange(of: modelo.guardadoTick) { _ in cerrar() }
        .onChange(of: grupoElegido) { _ in modelo.errorAccion = nil }
        .onChange(of: nombre) { _ in modelo.errorAccion = nil }
        .onChange(of: montoTexto) { _ in modelo.errorAccion = nil }
    }

    private func mosaicoTipo(_ tipo: TipoBien) -> some View {
        let elegido = grupoElegido == tipo.grupo
        return Button { grupoElegido = tipo.grupo } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    CirculoIcono(simbolo: tipo.icono, color: KipPastel.para(tipo.grupo), tamano: 48)
                    Text(tipo.etiqueta)
                        .font(.manrope(14, weight: .bold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(KipColor.text(scheme))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(elegido ? KipColor.accent.opacity(0.15) : KipColor.card(scheme))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(elegido ? KipColor.accent : KipColor.border(scheme), lineWidth: elegido ? 2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                if elegido {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(KipColor.accent)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func guardar() {
        guard let monto = monto else { return }
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        Task {
            await modelo.agregar(kind: kind, grupo: grupoElegido, nombre: nombreLimpio, monto: monto)
        }
    }
}

/// La hoja de edicion de un bien manual: el titulo es el nombre
/// actual; sin selector de tipo. Eliminar va sin confirmacion, como
/// en la Android.
struct HojaEditarBien: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: PatrimonioModelo
    let bien: BienManualDto
    @State private var nombre: String
    @State private var montoTexto: String

    init(modelo: PatrimonioModelo, bien: BienManualDto) {
        self.modelo = modelo
        self.bien = bien
        _nombre = State(initialValue: bien.nombre)
        _montoTexto = State(initialValue: numeroSinCeros(bien.monto))
    }

    private var monto: Double? { parseMontoConComa(montoTexto) }
    private var valido: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty && monto != nil && (monto ?? -1) >= 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(bien.nombre)
                        .font(.manrope(22, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    CampoKip(etiqueta: "Nombre", texto: $nombre)
                    CampoMontoKip(etiqueta: "Monto", texto: $montoTexto)
                    if let error = modelo.errorAccion {
                        Text(error)
                            .font(.manrope(14))
                            .foregroundStyle(Color.red)
                    }
                    Button("Eliminar de mi patrimonio") {
                        Task { await modelo.eliminar(bien: bien) }
                    }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(Color.red)
                    .disabled(modelo.accionEnCurso)
                    Color.clear.frame(height: 12)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            BotonPrimario(texto: modelo.accionEnCurso ? "Guardando…" : "Guardar cambios", cargando: modelo.accionEnCurso) {
                guardar()
            }
            .disabled(!valido || modelo.accionEnCurso)
            .opacity(!valido || modelo.accionEnCurso ? 0.55 : 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(KipColor.bg(scheme))
        .onAppear { modelo.errorAccion = nil }
        .onChange(of: modelo.guardadoTick) { _ in cerrar() }
        .onChange(of: nombre) { _ in modelo.errorAccion = nil }
        .onChange(of: montoTexto) { _ in modelo.errorAccion = nil }
    }

    private func guardar() {
        guard let monto = monto else { return }
        let nombreLimpio = nombre.trimmingCharacters(in: .whitespaces)
        Task { await modelo.editar(bien: bien, nombre: nombreLimpio, monto: monto) }
    }
}
