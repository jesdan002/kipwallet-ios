import SwiftUI

// La pantalla Pronostico (PronosticoScreen.kt de la Android): chips de
// 3/6 meses, la tarjeta del punto mas bajo, la grafica diaria con
// tooltip tactil, el bloque del plan de deudas con su interruptor, las
// cuentas y lo que viene. El servidor calcula TODO (serie, minimo,
// alerta y totales); la app solo pinta y escala la grafica con los
// puntos dados. Cambiar los chips o el interruptor recarga todo.

@MainActor
final class PronosticoModelo: ObservableObject {
    @Published var datos: Pronostico? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var meses = 3
    @Published var conPlanPedido = false

    func cargar() {
        cargando = true
        errorTexto = nil
        let mesesPedidos = meses
        let planPedido = conPlanPedido
        Task {
            do {
                datos = try await Api.pronostico(meses: mesesPedidos, plan: planPedido)
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
    }

    func elegirMeses(_ nuevos: Int) {
        if nuevos == meses { return }
        meses = nuevos
        cargar()
    }

    func alternarPlan(_ nuevo: Bool) {
        if nuevo == conPlanPedido { return }
        conPlanPedido = nuevo
        cargar()
    }
}

struct PronosticoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrarVista
    @StateObject private var modelo = PronosticoModelo()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { cerrarVista() } label: {
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
                Text("Pronóstico")
                    .font(.manrope(22, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
                if let datos = modelo.datos {
                    contenido(datos)
                }
            } reintentar: {
                modelo.cargar()
            }
        }
        .background(KipColor.bg(scheme))
        .task {
            if modelo.datos == nil { modelo.cargar() }
        }
    }

    private func contenido(_ datos: Pronostico) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                chips
                tarjetaHeroe(datos)
                if datos.serie.count >= 2 {
                    GraficaPronostico(serie: datos.serie)
                        .id("\(datos.meses)-\(datos.conPlan)")
                }
                Text("Saldo proyectado día a día. No incluye el gasto variable del día a día (comida, transporte), así que el saldo real bajará más que el proyectado.")
                    .font(.manrope(13))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                bloquePlan(datos)
                if !datos.porCuenta.isEmpty { bloquePorCuenta(datos) }
                if !datos.eventos.isEmpty { bloqueEventos(datos) }
                Color.clear.frame(height: 96)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach([3, 6], id: \.self) { opcion in
                let elegido = modelo.meses == opcion
                Button("\(opcion) meses") { modelo.elegirMeses(opcion) }
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(elegido ? KipColor.onAccent : KipColor.text(scheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(elegido ? KipColor.accent : KipColor.card(scheme))
                    .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegido ? 0 : 1))
                    .clipShape(Capsule())
            }
            Spacer()
        }
    }

    private func tarjetaHeroe(_ datos: Pronostico) -> some View {
        KipCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tu punto más bajo")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text(datos.saldoMinimoTexto)
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(datos.saldoMinimo < 0 ? Color.red : KipColor.text(scheme))
                Text("el \(datos.fechaSaldoMinimoTexto)")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text("Al cierre del periodo: \(datos.saldoFinalTexto) · Entran \(datos.totalIngresosTexto) · Salen \(datos.totalEgresosTexto)")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
                if let alerta = datos.alertaFechaTexto {
                    Text("Ojo: el saldo quedaría en negativo el \(alerta).")
                        .font(.manrope(15))
                        .foregroundStyle(Color.red)
                }
            }
        }
    }

    @ViewBuilder
    private func bloquePlan(_ datos: Pronostico) -> some View {
        if datos.tienePlan && datos.tieneDeudas {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Con mi plan de deudas")
                            .font(.manrope(17, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("Usa el pago de tu plan en vez de los mínimos sueltos.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Spacer()
                    // El interruptor refleja el con_plan de la RESPUESTA,
                    // no el pedido: si el servidor responde sin plan, se
                    // ve apagado.
                    KipInterruptor(activo: Binding(get: { datos.conPlan },
                                                   set: { modelo.alternarPlan($0) }))
                }
                if datos.conPlan, let comparacion = datos.comparacion {
                    KipCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Con tu plan ahorras \(comparacion.interesAhorradoTexto) en intereses.")
                                .font(.manrope(17, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("Libre de deudas: \(comparacion.fechaLibreConPlanTexto ?? "—") con el plan · \(comparacion.fechaLibreSinPlanTexto ?? "—") pagando solo mínimos.")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("Intereses: \(comparacion.interesConPlanTexto) con el plan · \(comparacion.interesSinPlanTexto) sin el plan.")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                    }
                }
            }
        } else if datos.avisoPlan == "sin_plan" {
            // Con aviso "sin_deudas" la Android no pinta nada.
            Text("Cuando guardes tu plan de deudas podrás ver aquí el pronóstico con ese plan aplicado.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
        }
    }

    private func bloquePorCuenta(_ datos: Pronostico) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POR CUENTA")
                .font(.manrope(12, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            ForEach(datos.porCuenta) { cuenta in
                HStack {
                    Text(cuenta.nombre)
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                        .lineLimit(1)
                    Spacer()
                    Text("\(cuenta.saldoInicialTexto) → \(cuenta.saldoFinalTexto)")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                }
            }
        }
    }

    private func bloqueEventos(_ datos: Pronostico) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LO QUE VIENE")
                .font(.manrope(12, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.bottom, 4)
            ForEach(Array(datos.eventos.enumerated()), id: \.offset) { _, evento in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(evento.titulo)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Text(evento.fechaTexto)
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        if let cuenta = evento.cuentaTexto {
                            Text("De tu cuenta \(cuenta)")
                                .font(.manrope(13))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                    Spacer(minLength: 4)
                    if let montoTexto = evento.montoTexto {
                        Text(montoTexto)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle((evento.monto ?? 0) > 0 ? KipColor.accent : KipColor.text(scheme))
                    }
                }
                .padding(.vertical, 8)
                Divider().background(KipColor.border(scheme))
            }
        }
    }
}

// MARK: - La grafica de la serie

/// La grafica diaria del Pronostico: escala desde la serie recibida
/// (sin forzar el cero), linea del cero solo si la serie lo cruza,
/// polilinea recta en Accent y tooltip tactil con gesto horizontal
/// (el vertical sigue siendo del scroll de la pantalla).
struct GraficaPronostico: View {
    @Environment(\.colorScheme) private var scheme
    let serie: [PronosticoPunto]
    @State private var seleccion: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                if let indice = seleccion, serie.indices.contains(indice) {
                    // Fecha y saldo formateados por el cliente.
                    ChipSuave(texto: "\(fechaLegible(serie[indice].fecha)) · \(dinero(serie[indice].saldo))",
                              color: KipPastel.azul)
                } else {
                    Text("Toca la gráfica para ver el saldo de un día")
                        .font(.manrope(13))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
            }
            .frame(height: 34)
            GeometryReader { geo in
                Canvas { contexto, tamano in
                    dibujar(contexto, tamano: tamano)
                }
                .frame(height: 160)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { valor in
                            // Solo el gesto predominantemente horizontal
                            // selecciona dia; el vertical es del scroll.
                            if abs(valor.translation.width) >= abs(valor.translation.height) {
                                seleccionar(x: valor.location.x, ancho: geo.size.width)
                            }
                        }
                        .onEnded { valor in
                            if abs(valor.translation.width) >= abs(valor.translation.height) {
                                seleccionar(x: valor.location.x, ancho: geo.size.width)
                            }
                        }
                )
            }
            .frame(height: 160)
        }
        .onChange(of: serie.count) { _ in seleccion = nil }
    }

    private func seleccionar(x: CGFloat, ancho: CGFloat) {
        let n = serie.count
        guard n >= 2, ancho > 0 else { return }
        let pasoX = ancho / CGFloat(n - 1)
        let indice = Int((Double(x / pasoX)).rounded())
        seleccion = min(max(indice, 0), n - 1)
    }

    private func dibujar(_ contexto: GraphicsContext, tamano: CGSize) {
        let n = serie.count
        guard n >= 2 else { return }
        let valores = serie.map { $0.saldo }
        let minimo = valores.min() ?? 0
        let maximo = valores.max() ?? 0
        let rango = (maximo - minimo) == 0 ? 1.0 : (maximo - minimo)
        let pasoX = tamano.width / CGFloat(n - 1)
        func punto(_ indice: Int) -> CGPoint {
            CGPoint(x: CGFloat(indice) * pasoX,
                    y: tamano.height - CGFloat((valores[indice] - minimo) / rango) * tamano.height)
        }
        if minimo < 0 && maximo > 0 {
            let yCero = tamano.height - CGFloat((0 - minimo) / rango) * tamano.height
            var linea = Path()
            linea.move(to: CGPoint(x: 0, y: yCero))
            linea.addLine(to: CGPoint(x: tamano.width, y: yCero))
            contexto.stroke(linea, with: .color(KipColor.border(scheme)), style: StrokeStyle(lineWidth: 1))
        }
        var camino = Path()
        for indice in 0..<n {
            let p = punto(indice)
            if indice == 0 { camino.move(to: p) } else { camino.addLine(to: p) }
        }
        contexto.stroke(camino, with: .color(KipColor.accent), style: StrokeStyle(lineWidth: 2))
        if let indice = seleccion, serie.indices.contains(indice) {
            let p = punto(indice)
            var guia = Path()
            guia.move(to: CGPoint(x: p.x, y: 0))
            guia.addLine(to: CGPoint(x: p.x, y: tamano.height))
            contexto.stroke(guia, with: .color(KipColor.border(scheme)), style: StrokeStyle(lineWidth: 1))
            contexto.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)),
                          with: .color(KipColor.accent))
            contexto.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)),
                          with: .color(.white))
        }
    }
}
