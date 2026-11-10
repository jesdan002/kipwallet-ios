import SwiftUI

// La pantalla Recurrentes (RecurrentesScreen.kt de la Android):
// pestanas Proximos/Todos, mini calendario con su detalle del dia,
// calendario extendido, tarjeta "Seguro para gastar", cargos que vencen
// antes del pago, cargos recientes y los grupos con su orden.

let ORDENES_RECURRENTES: [(String, String)] = [
    ("tipo", "Por tipo"), ("cuenta", "Por cuenta"), ("monto", "Por monto"),
    ("fecha", "Por fecha de cobro"), ("frecuencia", "Por frecuencia"), ("alfabetico", "Alfabético"),
]

@MainActor
final class RecurrentesModelo: ObservableObject {
    @Published var datos: RecurrentesRespuesta? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var orden = "monto"
    @Published var calendario: CalendarioRespuesta? = nil
    @Published var mesCalendario: String

    init() {
        let formato = DateFormatter()
        formato.calendar = Calendar(identifier: .gregorian)
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.dateFormat = "yyyy-MM"
        mesCalendario = formato.string(from: Date())
    }

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            datos = try await Api.recurrentes(orden: orden)
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

    func cambiarOrden(_ clave: String) async {
        if clave == orden && datos != nil { return }
        orden = clave
        await cargar()
    }

    func cargarCalendario() async {
        do {
            calendario = try await Api.calendario(mes: mesCalendario)
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar() }
        } catch {}
    }

    func moverMes(_ delta: Int) async {
        let partes = mesCalendario.split(separator: "-")
        guard partes.count == 2, var anio = Int(partes[0]), var mes = Int(partes[1]) else { return }
        mes += delta
        while mes > 12 { mes -= 12; anio += 1 }
        while mes < 1 { mes += 12; anio -= 1 }
        mesCalendario = "\(anio)-\(String(format: "%02d", mes))"
        await cargarCalendario()
    }
}

struct RecurrentesView: View {
    @Environment(\.colorScheme) private var scheme
    var conVolver = false
    var alIrAAjustes: () -> Void = {}
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo = RecurrentesModelo()
    @State private var pestana = 0
    @State private var vistaProximos = "calendario"
    @State private var diaElegido: String? = nil
    @State private var calendarioGrande = false
    @State private var dialogoOrden = false
    @State private var dialogoSeguro = false

    var body: some View {
        Group {
            if calendarioGrande, let cal = modelo.calendario {
                CalendarioExtendidoView(calendario: cal, datos: modelo.datos,
                                        alVolver: { calendarioGrande = false },
                                        alMes: { delta in Task { await modelo.moverMes(delta) } })
            } else {
                principal
            }
        }
        .task {
            if modelo.datos == nil {
                await modelo.cargar()
                await modelo.cargarCalendario()
            }
        }
        .alert("¿Cómo se calcula?", isPresented: $dialogoSeguro) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Tomamos el dinero que tienes hoy en tus cuentas de depósito y restamos los cobros recurrentes que vencen antes de tu próximo día de pago. Lo que queda es seguro para gastar sin quedarte corto para esos cobros.")
        }
        .confirmationDialog("Ordenar por", isPresented: $dialogoOrden, titleVisibility: .visible) {
            ForEach(ORDENES_RECURRENTES, id: \.0) { opcion in
                Button(opcion.1 + (modelo.orden == opcion.0 ? " ✓" : "")) {
                    Task { await modelo.cambiarOrden(opcion.0) }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var principal: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if conVolver {
                    Button { cerrar() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                Text("Recurrentes")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, conVolver ? 4 : 16)
            .padding(.top, 8)
            Picker("", selection: $pestana) {
                Text("Próximos").tag(0)
                Text("Todos").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
                if let datos = modelo.datos {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            if pestana == 0 {
                                pestanaProximos(datos)
                            } else {
                                pestanaTodos(datos)
                            }
                            Color.clear.frame(height: 110)
                        }
                    }
                    .refreshable {
                        await modelo.cargar()
                        await modelo.cargarCalendario()
                    }
                }
            } reintentar: {
                Task { await modelo.cargar() }
            }
        }
        .background(KipColor.bg(scheme))
    }

    // MARK: - Pestana Proximos

    @ViewBuilder
    private func pestanaProximos(_ datos: RecurrentesRespuesta) -> some View {
        HStack(spacing: 8) {
            chipVista("Calendario", clave: "calendario")
            chipVista("Lista", clave: "lista")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        if vistaProximos == "calendario" {
            if let cal = modelo.calendario {
                MiniCalendarioView(calendario: cal, diaElegido: $diaElegido,
                                   alMes: { delta in Task { await modelo.moverMes(delta) } },
                                   alExpandir: { calendarioGrande = true })
            }
        } else {
            tarjetaLoQueViene(datos)
        }
        tarjetaAntesDelPago(datos)
        bloqueAntesDelPago(datos)
        bloqueRecientes(datos)
    }

    private func chipVista(_ texto: String, clave: String) -> some View {
        let elegida = vistaProximos == clave
        return Button(texto) { vistaProximos = clave }
            .font(.manrope(14, weight: .bold))
            .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(elegida ? KipColor.accent : KipColor.card(scheme))
            .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
            .clipShape(Capsule())
    }

    private func cargosPorVencer(_ datos: RecurrentesRespuesta, limite: Int) -> [RecurrenteItem] {
        datos.cargos
            .filter { !$0.cancelada }
            .sorted { ($0.dias ?? Int.max) < ($1.dias ?? Int.max) }
            .prefix(limite)
            .map { $0 }
    }

    private func tarjetaLoQueViene(_ datos: RecurrentesRespuesta) -> some View {
        let cargos = cargosPorVencer(datos, limite: 10)
        return Group {
            if !cargos.isEmpty {
                KipCard(padding: 0) {
                    VStack(spacing: 0) {
                        tituloInterno("Lo que viene")
                        ForEach(cargos, id: \.comercio) { cargo in
                            FilaRecurrenteCompacta(cargo: cargo)
                            Divider().background(KipColor.border(scheme)).padding(.leading, 68)
                        }
                        Color.clear.frame(height: 6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func tituloInterno(_ texto: String) -> some View {
        Text(texto)
            .font(.manrope(16, weight: .bold))
            .foregroundStyle(KipColor.text(scheme))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private func tituloSeccion(_ texto: String) -> some View {
        Text(texto)
            .font(.manrope(16, weight: .bold))
            .foregroundStyle(KipColor.text(scheme))
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private func tarjetaAntesDelPago(_ datos: RecurrentesRespuesta) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 8) {
                if let antes = datos.antesDelPago {
                    HStack {
                        Text("Seguro para gastar")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer()
                        Button { dialogoSeguro = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .buttonStyle(.plain)
                    }
                    Text(antes.seguroTexto)
                        .font(.manrope(28, weight: .heavy))
                        .foregroundStyle(antes.seguro >= 0 ? KipColor.text(scheme) : Color.red)
                    Text("Tienes \(antes.efectivoTexto) en tus cuentas.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Cobros antes de tu pago (\(antes.proximoPagoTexto)): −\(antes.totalCobrosTexto)")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                } else {
                    Text("¿Cuánto puedes gastar sin quedarte corto?")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Configura tu día de pago y aquí verás cuánto tienes, cuánto se va en cobros antes de ese día y cuánto es seguro gastar.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Button("Configurar mi día de pago") { alIrAAjustes() }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.horizontal, 16)
                        .frame(height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func bloqueAntesDelPago(_ datos: RecurrentesRespuesta) -> some View {
        if let antes = datos.antesDelPago, !antes.cobros.isEmpty {
            tituloSeccion("Vence antes de tu pago")
            ForEach(antes.cobros) { cobro in
                HStack(spacing: 12) {
                    CirculoComercio(nombre: cobro.comercio, tamano: 42, logoUrl: cobro.logoUrl)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cobro.comercio)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(textoDias(cobro.dias))
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    Text(cobro.montoTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().background(KipColor.border(scheme)).padding(.leading, 70)
            }
        } else if datos.antesDelPago == nil && vistaProximos == "calendario" {
            tituloSeccion("Lo que viene")
            ForEach(cargosPorVencer(datos, limite: 6), id: \.comercio) { cargo in
                FilaRecurrenteCompleta(cargo: cargo)
                Divider().background(KipColor.border(scheme)).padding(.leading, 16)
            }
        }
    }

    @ViewBuilder
    private func bloqueRecientes(_ datos: RecurrentesRespuesta) -> some View {
        if let recientes = datos.recientes, (recientes.cantidad ?? 0) > 0 {
            tituloSeccion("Cargos recientes")
            Text(resumenRecientes(recientes))
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            ForEach(recientes.filas) { fila in
                HStack(spacing: 12) {
                    ZStack(alignment: .bottomTrailing) {
                        CirculoComercio(nombre: fila.comercio, tamano: 42, logoUrl: fila.logoUrl)
                        ZStack {
                            Circle().fill(KipColor.gradientEnd)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 17, height: 17)
                        .offset(x: 3, y: 3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fila.comercio)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(fechaPalabras(fila.fecha))
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    Text(fila.montoTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                Divider().background(KipColor.border(scheme)).padding(.leading, 70)
            }
        }
    }

    private func resumenRecientes(_ recientes: RecientesRecurrentes) -> String {
        let cantidad = recientes.cantidad ?? 0
        if cantidad == 1 {
            return "En los últimos 7 días tuviste 1 cargo recurrente por \(recientes.totalTexto ?? "")."
        }
        return "En los últimos 7 días tuviste \(cantidad) cargos recurrentes por \(recientes.totalTexto ?? "")."
    }

    // MARK: - Pestana Todos

    @ViewBuilder
    private func pestanaTodos(_ datos: RecurrentesRespuesta) -> some View {
        HStack {
            Text("Ordenar por: \(ORDENES_RECURRENTES.first { $0.0 == modelo.orden }?.1 ?? modelo.orden)")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            Button("Cambiar") { dialogoOrden = true }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.horizontal, 14)
                .frame(height: 38)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        if datos.cargos.isEmpty {
            Text("Todavía no detectamos cargos que se repitan.")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(16)
        } else if !datos.grupos.isEmpty {
            ForEach(datos.grupos, id: \.clave) { grupo in
                let filas = datos.cargos.filter { $0.tipo == grupo.clave }
                if !filas.isEmpty {
                    KipCard(padding: 0) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("\(grupo.cantidad ?? filas.count) \(grupo.etiqueta.uppercased())")
                                    .font(.manrope(12, weight: .bold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                Spacer()
                                Text("\(grupo.totalAnualTexto ?? "") al año")
                                    .font(.manrope(12, weight: .bold))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 4)
                            ForEach(filas, id: \.comercio) { cargo in
                                FilaRecurrenteCompacta(cargo: cargo)
                                Divider().background(KipColor.border(scheme)).padding(.leading, 68)
                            }
                            Color.clear.frame(height: 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        } else {
            ForEach(datos.cargos, id: \.comercio) { cargo in
                FilaRecurrenteCompleta(cargo: cargo)
                Divider().background(KipColor.border(scheme)).padding(.leading, 16)
            }
        }
    }
}

// MARK: - Filas de cargo

struct FilaRecurrenteCompacta: View {
    @Environment(\.colorScheme) private var scheme
    let cargo: RecurrenteItem

    var body: some View {
        HStack(spacing: 12) {
            CirculoComercio(nombre: cargo.comercio, tamano: 40, logoUrl: cargo.logoUrl)
            VStack(alignment: .leading, spacing: 3) {
                Text(cargo.comercio)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if let frecuencia = cargo.frecuenciaTexto ?? cargo.frecuencia {
                        Text(frecuencia)
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    if cargo.cancelada {
                        ChipSuave(texto: cargo.estadoCancelacion ?? "Cancelada", color: KipPastel.verde, compacto: true)
                    }
                }
            }
            Spacer()
            Text(cargo.montoTexto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct FilaRecurrenteCompleta: View {
    @Environment(\.colorScheme) private var scheme
    let cargo: RecurrenteItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                CirculoComercio(nombre: cargo.comercio, tamano: 40, logoUrl: cargo.logoUrl)
                Text(cargo.comercio)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                Spacer()
                Text(cargo.montoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            HStack(spacing: 8) {
                if let frecuencia = cargo.frecuenciaTexto ?? cargo.frecuencia {
                    ChipSuave(texto: frecuencia, color: KipPastel.azul)
                }
                if cargo.cancelada {
                    ChipSuave(texto: cargo.estadoCancelacion ?? "Cancelada", color: KipPastel.verde)
                }
            }
            if !lineaDetalle.isEmpty {
                Text(lineaDetalle)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var lineaDetalle: String {
        var partes: [String] = []
        if let fecha = cargo.proximaFecha {
            var texto = "Próximo: \(fechaLegible(fecha))"
            if let dias = cargo.dias { texto += " (\(textoDias(dias)))" }
            partes.append(texto)
        }
        if let mensual = cargo.costoMensualTexto {
            partes.append("\(mensual) al mes")
        }
        if let cuenta = cargo.cuenta, !cuenta.isEmpty {
            partes.append(cuenta)
        }
        return partes.joined(separator: " · ")
    }
}

// MARK: - Calendarios

/// Las celdas del mes lunes-primero desde el DTO del servidor.
func celdasDelMes(_ calendario: CalendarioRespuesta) -> [(fecha: String, dia: CalendarioDia?)] {
    let partes = calendario.mes.split(separator: "-")
    guard partes.count == 2, let anio = Int(partes[0]), let mes = Int(partes[1]) else { return [] }
    var cal = Calendar(identifier: .gregorian)
    cal.firstWeekday = 2
    var componentes = DateComponents()
    componentes.year = anio
    componentes.month = mes
    componentes.day = 1
    guard let primero = cal.date(from: componentes),
          let rango = cal.range(of: .day, in: .month, for: primero) else { return [] }
    let desplazamiento = (cal.component(.weekday, from: primero) + 5) % 7
    let formato = DateFormatter()
    formato.calendar = Calendar(identifier: .gregorian)
    formato.locale = Locale(identifier: "en_US_POSIX")
    formato.dateFormat = "yyyy-MM-dd"
    var resultado: [(String, CalendarioDia?)] = []
    for _ in 0..<desplazamiento { resultado.append(("", nil)) }
    for diaNum in rango {
        componentes.day = diaNum
        let fecha = formato.string(from: cal.date(from: componentes)!)
        resultado.append((fecha, calendario.dias.first { $0.fecha == fecha }))
    }
    return resultado
}

/// El monto de la pastilla sin centavos ("-$1,099.00" -> "-$1,099").
func sinCentavos(_ texto: String) -> String {
    if texto.count > 3, texto.suffix(3).first == "." {
        return String(texto.dropLast(3))
    }
    return texto
}

struct MiniCalendarioView: View {
    @Environment(\.colorScheme) private var scheme
    let calendario: CalendarioRespuesta
    @Binding var diaElegido: String?
    var alMes: (Int) -> Void = { _ in }
    var alExpandir: () -> Void = {}

    var body: some View {
        KipCard(padding: 12) {
            VStack(spacing: 8) {
                HStack {
                    Button { alMes(-1) } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(calendario.mesTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    Button { alMes(1) } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .buttonStyle(.plain)
                    Button { alExpandir() } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 0) {
                    ForEach(["L", "M", "M", "J", "V", "S", "D"], id: \.self) { letra in
                        Text(letra)
                            .font(.manrope(11, weight: .heavy))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                    ForEach(Array(celdasDelMes(calendario).enumerated()), id: \.offset) { _, celda in
                        if celda.fecha.isEmpty {
                            Color.clear.aspectRatio(0.78, contentMode: .fit)
                        } else {
                            celdaMini(celda)
                        }
                    }
                }
                Divider().background(KipColor.border(scheme))
                detalleDia
                if let resumen = calendario.resumen {
                    Text("Cobros del mes: \(resumen.cobrosTotalTexto ?? "") · Ya entró: \(resumen.ingresosTotalTexto ?? "") · Ya salió: \(resumen.gastosTotalTexto ?? "")")
                        .font(.manrope(12))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: calendario.mes) { _ in diaElegido = nil }
    }

    private func celdaMini(_ celda: (fecha: String, dia: CalendarioDia?)) -> some View {
        let diaNum = Int(celda.fecha.suffix(2)) ?? 0
        let eventos = celda.dia?.eventos ?? []
        let conMonto = eventos.first { $0.montoTexto != nil }
        let elegido = diaElegido == celda.fecha
        return Button {
            diaElegido = celda.fecha
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    if celda.dia?.esHoy == true {
                        Circle().fill(KipColor.accent)
                    }
                    Text("\(diaNum)")
                        .font(.manrope(12, weight: .bold))
                        .foregroundStyle(colorNumero(celda))
                }
                .frame(width: 20, height: 20)
                if let primero = eventos.first {
                    CirculoComercio(nombre: primero.titulo, tamano: 15, logoUrl: primero.logoUrl)
                }
                if let conMonto = conMonto, let texto = conMonto.montoTexto {
                    Text(sinCentavos(texto))
                        .font(.manrope(10, weight: .heavy))
                        .foregroundStyle(conMonto.tipo == "pago" ? KipPastel.verde : KipPastel.azul)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background((conMonto.tipo == "pago" ? KipPastel.verde : KipPastel.azul).opacity(0.18))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
                if eventos.count > 1 {
                    Text("+\(eventos.count - 1)")
                        .font(.manrope(11, weight: .heavy))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
            .padding(1)
            .frame(maxWidth: .infinity)
            .aspectRatio(0.78, contentMode: .fit)
            .background(elegido ? KipColor.elevated(scheme) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func colorNumero(_ celda: (fecha: String, dia: CalendarioDia?)) -> Color {
        if celda.dia?.esHoy == true { return KipColor.onAccent }
        if celda.dia?.riesgo == true { return Color.red }
        return KipColor.text(scheme)
    }

    @ViewBuilder
    private var detalleDia: some View {
        if let fecha = diaElegido {
            if let dia = calendario.dias.first(where: { $0.fecha == fecha }), !dia.eventos.isEmpty {
                DiaDetalleCalendario(dia: dia)
            } else {
                Text("Este día no tiene cobros.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// El detalle de un dia del calendario (eventos con su texto propio).
struct DiaDetalleCalendario: View {
    @Environment(\.colorScheme) private var scheme
    let dia: CalendarioDia

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dia.fechaTexto)
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            ForEach(dia.eventos, id: \.titulo) { evento in
                HStack(spacing: 10) {
                    CirculoComercio(nombre: evento.titulo, tamano: 30, logoUrl: evento.logoUrl)
                    Text(textoEvento(evento))
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    if let monto = evento.montoTexto {
                        Text(monto)
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func textoEvento(_ evento: CalendarioEvento) -> String {
        var texto: String
        switch evento.tipo {
        case "pago": texto = "Día de pago"
        case "vencimiento": texto = "Vence \(evento.titulo)"
        default: texto = evento.titulo
        }
        if evento.pagado { texto += " · pagado" }
        return texto
    }
}

struct CalendarioExtendidoView: View {
    @Environment(\.colorScheme) private var scheme
    let calendario: CalendarioRespuesta
    let datos: RecurrentesRespuesta?
    var alVolver: () -> Void = {}
    var alMes: (Int) -> Void = { _ in }
    @State private var diaElegido: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button { alVolver() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text(calendario.mesTexto)
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Button { alMes(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .buttonStyle(.plain)
                Button { alMes(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(["L", "M", "M", "J", "V", "S", "D"], id: \.self) { letra in
                            Text(letra)
                                .font(.manrope(12, weight: .bold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 8)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                        ForEach(Array(celdasDelMes(calendario).enumerated()), id: \.offset) { _, celda in
                            if celda.fecha.isEmpty {
                                Color.clear.aspectRatio(0.62, contentMode: .fit)
                            } else {
                                celdaExtendida(celda)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    detalle
                    tarjetaTotales
                    Color.clear.frame(height: 110)
                }
            }
        }
        .background(KipColor.bg(scheme))
        .onChange(of: calendario.mes) { _ in diaElegido = nil }
    }

    private func celdaExtendida(_ celda: (fecha: String, dia: CalendarioDia?)) -> some View {
        let diaNum = Int(celda.fecha.suffix(2)) ?? 0
        let eventos = celda.dia?.eventos ?? []
        let conMonto = eventos.first { $0.montoTexto != nil }
        let elegido = diaElegido == celda.fecha
        return Button {
            diaElegido = celda.fecha
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(diaNum)")
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(celda.dia?.riesgo == true ? Color.red : KipColor.text(scheme))
                if let primero = eventos.first {
                    CirculoComercio(nombre: primero.titulo, tamano: 22, logoUrl: primero.logoUrl)
                }
                if let conMonto = conMonto, let texto = conMonto.montoTexto {
                    Text(sinCentavos(texto))
                        .font(.manrope(12, weight: .bold))
                        .foregroundStyle(conMonto.tipo == "pago" ? KipPastel.verde : KipPastel.azul)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background((conMonto.tipo == "pago" ? KipPastel.verde : KipPastel.azul).opacity(0.18))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
                if eventos.count > 1 {
                    Text("+\(eventos.count - 1)")
                        .font(.manrope(11, weight: .heavy))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                Spacer(minLength: 0)
            }
            .padding(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .aspectRatio(0.62, contentMode: .fit)
            .background(fondoCelda(celda, elegido: elegido))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KipColor.border(scheme), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func fondoCelda(_ celda: (fecha: String, dia: CalendarioDia?), elegido: Bool) -> Color {
        if elegido { return KipColor.elevated(scheme) }
        if celda.dia?.esHoy == true { return KipColor.accent.opacity(0.12) }
        return Color.clear
    }

    @ViewBuilder
    private var detalle: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let fecha = diaElegido {
                if let dia = calendario.dias.first(where: { $0.fecha == fecha }), !dia.eventos.isEmpty {
                    DiaDetalleCalendario(dia: dia)
                } else {
                    Text("Este día no tiene cobros.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            } else {
                Text("Toca un día para ver sus cobros.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tarjetaTotales: some View {
        let totales = totalesPorTipo()
        if !totales.isEmpty {
            KipCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(totales, id: \.etiqueta) { entrada in
                        HStack {
                            Text(entrada.etiqueta)
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            Text(dinero(entrada.total))
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    Color.clear.frame(height: 8)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// Totales del mes por tipo de cargo (suma en cliente, como la
    /// Android: se agrupa por el tipo del recurrente que coincide con
    /// el titulo del evento; el resto cae en "Otros").
    private func totalesPorTipo() -> [(etiqueta: String, total: Double)] {
        guard let datos = datos else { return [] }
        var sumas: [String: Double] = [:]
        for dia in calendario.dias {
            for evento in dia.eventos where evento.tipo != "pago" {
                let tipo = datos.cargos.first { $0.comercio.lowercased() == evento.titulo.lowercased() }?.tipo ?? "otros"
                sumas[tipo, default: 0] += evento.monto ?? 0
            }
        }
        var resultado: [(String, Double)] = []
        for grupo in datos.grupos {
            if let total = sumas[grupo.clave], total > 0 {
                resultado.append((grupo.etiqueta, total))
            }
        }
        if let otros = sumas["otros"], otros > 0 {
            resultado.append(("Otros", otros))
        }
        return resultado
    }
}
