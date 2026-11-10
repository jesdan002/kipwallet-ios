import SwiftUI

// La pantalla Deudas (DeudasScreen.kt de la Android): tarjeta heroe con
// la fecha de libertad, grafica de dos curvas en tiempo real, filas
// desplegables con editor de datos y el simulador con debounce de
// 400 ms. Todo el calculo vive en el servidor.

@MainActor
final class DeudasModelo: ObservableObject {
    @Published var datos: DeudasRespuesta? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var simulacion: SimulacionDeudas? = nil
    @Published var simulando = false
    @Published var errorSimulacion: String? = nil
    @Published var extraSimulacion: Double = 0
    @Published var estrategiaSimulacion: String = "interes_primero"
    @Published var guardandoPlan = false
    @Published var errorGuardarPlan: String? = nil
    @Published var planGuardado = false

    private var tareaSimulacion: Task<Void, Never>? = nil
    private var primeraCarga = true

    var estrategiasDisponibles: [(clave: String, etiqueta: String)] {
        var lista = [("interes_primero", "Interés primero"), ("efecto_domino", "Efecto dominó")]
        if let plan = datos?.plan, !lista.contains(where: { $0.0 == plan.estrategia }) {
            lista.append((plan.estrategia, plan.estrategiaTexto))
        }
        return lista
    }

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            let r = try await Api.deudas()
            datos = r
            if primeraCarga, let plan = r.plan {
                extraSimulacion = plan.extra
                estrategiaSimulacion = plan.estrategia
                primeraCarga = false
            }
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

    func programarSimulacion() {
        planGuardado = false
        tareaSimulacion?.cancel()
        let extra = extraSimulacion
        let estrategia = estrategiaSimulacion
        tareaSimulacion = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            simulando = true
            errorSimulacion = nil
            do {
                let r = try await Api.simularDeudas(extra: extra, estrategia: estrategia)
                if Task.isCancelled { return }
                simulacion = r
                simulando = false
            } catch let e as ApiError {
                if Task.isCancelled { return }
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorSimulacion = e.errorDescription
                simulando = false
            } catch {
                if Task.isCancelled { return }
                errorSimulacion = "No se pudo hacer la simulación."
                simulando = false
            }
        }
    }

    func guardarPlan() async {
        guardandoPlan = true
        errorGuardarPlan = nil
        do {
            let r = try await Api.guardarPlanDeudas(extra: extraSimulacion, estrategia: estrategiaSimulacion)
            datos = r
            simulacion = nil
            if let plan = r.plan {
                extraSimulacion = plan.extra
                estrategiaSimulacion = plan.estrategia
            }
            planGuardado = true
            guardandoPlan = false
        } catch let e as ApiError {
            guardandoPlan = false
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorGuardarPlan = e.errorDescription
        } catch {
            guardandoPlan = false
            errorGuardarPlan = "No se pudo guardar tu plan."
        }
    }

    func volverAMiPlan() {
        tareaSimulacion?.cancel()
        simulacion = nil
        errorSimulacion = nil
        if let plan = datos?.plan {
            extraSimulacion = plan.extra
            estrategiaSimulacion = plan.estrategia
        }
    }
}

struct DeudasView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = DeudasModelo()
    @State private var expandidas: Set<String> = []
    @State private var editandoId: Int? = nil

    var body: some View {
        EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
            if let datos = modelo.datos {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Deudas")
                            .font(.manrope(20, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        tarjetaHeroe(datos)
                        if serieActiva(datos).count >= 2 {
                            tarjetaGrafica(datos)
                        }
                        Text("Tus deudas")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        if datos.deudas.isEmpty {
                            Text("No tienes deudas registradas. Vas libre.")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .padding(16)
                        } else {
                            ForEach(datos.deudas) { deuda in
                                FilaDeudaView(deuda: deuda,
                                              expandida: expandidas.contains(claveDeuda(deuda)),
                                              editando: editandoId == deuda.id,
                                              alExpandir: {
                                                  let clave = claveDeuda(deuda)
                                                  if expandidas.contains(clave) { expandidas.remove(clave) } else { expandidas.insert(clave) }
                                              },
                                              alEditar: { editandoId = deuda.id },
                                              alCerrarEditor: { editandoId = nil },
                                              alGuardar: { Task { await modelo.cargar() } })
                                Divider().background(KipColor.border(scheme)).padding(.leading, 16)
                            }
                        }
                        TarjetaSimuladorDeudas(modelo: modelo)
                            .padding(.top, 16)
                        Color.clear.frame(height: 110)
                    }
                }
                .refreshable { await modelo.cargar() }
            }
        } reintentar: {
            Task { await modelo.cargar() }
        }
        .task {
            if modelo.datos == nil { await modelo.cargar() }
        }
    }

    private func claveDeuda(_ deuda: DeudaItem) -> String {
        deuda.nombre + (deuda.mascara ?? "")
    }

    // MARK: - Heroe

    private func serieActiva(_ datos: DeudasRespuesta) -> [SeriePunto] {
        if let sim = modelo.simulacion, !sim.serie.isEmpty { return sim.serie }
        return datos.serie
    }

    private var haySimulacion: Bool { modelo.simulacion != nil }

    private func tarjetaHeroe(_ datos: DeudasRespuesta) -> some View {
        let sim = modelo.simulacion
        let fechaTexto: String? = sim != nil ? sim?.fechaLibertadTexto : datos.fechaLibertadTexto
        let estrategiaTexto: String = {
            if let sim = sim, let clave = sim.estrategia {
                return modelo.estrategiasDisponibles.first { $0.0 == clave }?.1 ?? datos.plan?.estrategiaTexto ?? ""
            }
            return datos.plan?.estrategiaTexto ?? ""
        }()
        let presupuestoTexto: String? = sim != nil ? sim?.presupuestoMensualTexto : datos.presupuestoMensualTexto
        let interesTexto: String? = sim != nil ? sim?.interesTotalTexto : datos.interesTotalTexto
        return VStack(alignment: .leading, spacing: 6) {
            Text(haySimulacion ? "LIBRE DE DEUDAS EN · SIMULACIÓN" : "LIBRE DE DEUDAS EN")
                .font(.manrope(11, weight: .heavy))
                .kerning(1.2)
                .foregroundStyle(KipColor.onAccent)
            Text(fechaTexto ?? "Sin fecha todavía")
                .font(.manrope(36, weight: .heavy))
                .foregroundStyle(KipColor.onAccent)
            Text(detalleHeroe(estrategia: estrategiaTexto, presupuesto: presupuestoTexto, interes: interesTexto))
                .font(.manrope(14))
                .foregroundStyle(KipColor.onAccent)
            if modelo.simulando {
                Text("Calculando…")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.onAccent)
            } else if fechaTexto == nil {
                Text("Con los pagos actuales el plan no alcanza a liquidar todo; prueba subir el abono extra en el simulador.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.onAccent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func detalleHeroe(estrategia: String, presupuesto: String?, interes: String?) -> String {
        var texto = estrategia
        if let presupuesto = presupuesto { texto += " · Pagas \(presupuesto) al mes" }
        if let interes = interes { texto += " · Intereses por pagar: \(interes)" }
        return texto
    }

    // MARK: - Grafica

    private func tarjetaGrafica(_ datos: DeudasRespuesta) -> some View {
        let activa = serieActiva(datos)
        let minimos = datos.serieMinimos
        return KipCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Cómo baja tu deuda")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                GraficaDeudas(activa: activa, minimos: minimos)
                    .frame(height: 168)
                HStack {
                    Text("\(activa.first?.etiqueta ?? "") · \(activa.first?.saldoTexto ?? "")")
                    Spacer()
                    Text("\(activa.last?.etiqueta ?? "") · \(activa.last?.saldoTexto ?? "")")
                }
                .font(.manrope(12))
                .foregroundStyle(KipColor.textSecondary(scheme))
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(KipColor.gradientEnd).frame(width: 10, height: 10)
                        Text(haySimulacion ? "Con esta simulación" : "Con tu plan")
                    }
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3).fill(KipColor.textSecondary(scheme)).frame(width: 10, height: 10)
                        Text("Solo pagos mínimos")
                    }
                    Spacer()
                }
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

/// La grafica de deudas: eje X en meses reales desde el primer punto,
/// area bajo la curva activa y la de minimos punteada (Canvas).
struct GraficaDeudas: View {
    let activa: [SeriePunto]
    let minimos: [SeriePunto]

    var body: some View {
        Canvas { contexto, tamano in
            func mesesDesde(_ inicio: String, hasta mes: String) -> CGFloat {
                let a = inicio.split(separator: "-")
                let b = mes.split(separator: "-")
                guard a.count == 2, b.count == 2, let aA = Int(a[0]), let aM = Int(a[1]), let bA = Int(b[0]), let bM = Int(b[1]) else { return 0 }
                return CGFloat((bA - aA) * 12 + (bM - aM))
            }
            guard let primerMes = activa.first?.mes else { return }
            let maxX = max(mesesDesde(primerMes, hasta: activa.last?.mes ?? primerMes),
                           mesesDesde(primerMes, hasta: minimos.last?.mes ?? primerMes), 1)
            let maxY = max((activa + minimos).compactMap { $0.saldo }.max() ?? 1, 1)
            func punto(_ p: SeriePunto) -> CGPoint {
                let x = mesesDesde(primerMes, hasta: p.mes ?? primerMes) / maxX * tamano.width
                let y = tamano.height - CGFloat((p.saldo ?? 0) / maxY) * (tamano.height - 8)
                return CGPoint(x: x, y: y)
            }
            // Area bajo la curva activa
            if activa.count >= 2 {
                var area = Path()
                area.move(to: CGPoint(x: 0, y: tamano.height))
                for p in activa { area.addLine(to: punto(p)) }
                area.addLine(to: CGPoint(x: punto(activa[activa.count - 1]).x, y: tamano.height))
                area.closeSubpath()
                contexto.fill(area, with: .color(KipColor.gradientEnd.opacity(0.15)))
            }
            // Minimos punteada
            if minimos.count >= 2 {
                var linea = Path()
                for (i, p) in minimos.enumerated() {
                    if i == 0 { linea.move(to: punto(p)) } else { linea.addLine(to: punto(p)) }
                }
                contexto.stroke(linea, with: .color(Color.gray.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: [10, 8]))
            }
            // Activa solida
            if activa.count >= 2 {
                var linea = Path()
                for (i, p) in activa.enumerated() {
                    if i == 0 { linea.move(to: punto(p)) } else { linea.addLine(to: punto(p)) }
                }
                contexto.stroke(linea, with: .color(KipColor.gradientEnd), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

// MARK: - Fila de deuda

struct FilaDeudaView: View {
    @Environment(\.colorScheme) private var scheme
    let deuda: DeudaItem
    let expandida: Bool
    let editando: Bool
    var alExpandir: () -> Void = {}
    var alEditar: () -> Void = {}
    var alCerrarEditor: () -> Void = {}
    var alGuardar: () -> Void = {}

    @State private var aprTexto = ""
    @State private var minimoTexto = ""
    @State private var diaTexto = ""
    @State private var errorEditor: String? = nil
    @State private var guardando = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: alExpandir) {
                HStack(spacing: 12) {
                    CirculoComercio(nombre: deuda.banco ?? deuda.nombre, tamano: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(deuda.nombre)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .lineLimit(1)
                        if let mascara = deuda.mascara, !mascara.isEmpty {
                            Text("••••\(mascara)")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                    Spacer()
                    Text(deuda.saldoTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Image(systemName: expandida ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if expandida {
                VStack(alignment: .leading, spacing: 6) {
                    if let banco = deuda.banco, !banco.isEmpty {
                        filaDato("Banco", banco)
                    }
                    filaDato("Interés (APR)", deuda.aprTexto ?? "Falta")
                    filaDato("Pago mínimo", deuda.pagoMinimoTexto ?? "Falta")
                    filaDato("Vencimiento", deuda.diaVencimiento.map { "Día \($0) de cada mes" } ?? "Falta")
                    if deuda.liquidada {
                        Text("Ya está liquidada.")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.leading, 52)
                    }
                    if editando {
                        editor
                    } else {
                        Button(faltaAlgunDato ? "Completar datos" : "Editar datos") {
                            precargar()
                            alEditar()
                        }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                        .padding(.leading, 40)
                        .padding(.top, 4)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    private var faltaAlgunDato: Bool {
        deuda.aprTexto == nil || deuda.pagoMinimoTexto == nil || deuda.diaVencimiento == nil
    }

    private func filaDato(_ etiqueta: String, _ valor: String) -> some View {
        HStack {
            Text(etiqueta)
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            Text(valor)
                .font(.manrope(14))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.leading, 52)
        .padding(.trailing, 16)
    }

    private func precargar() {
        aprTexto = deuda.apr.map { numeroSinCeros($0) } ?? ""
        minimoTexto = deuda.pagoMinimo.map { numeroSinCeros($0) } ?? ""
        diaTexto = deuda.diaVencimiento.map { String($0) } ?? ""
        errorEditor = nil
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            CampoKip(etiqueta: "Interés (APR), % al año", texto: $aprTexto, tecladoNumero: true)
            CampoKip(etiqueta: "Pago mínimo, $ al mes", texto: $minimoTexto, tecladoNumero: true)
            CampoKip(etiqueta: "Día de vencimiento (1 a 31)", texto: $diaTexto, tecladoNumero: true)
            Text("Quedan guardados como datos tuyos: el banco no los cambia.")
                .font(.manrope(12))
                .foregroundStyle(KipColor.textSecondary(scheme))
            if let errorEditor = errorEditor {
                Text(errorEditor)
                    .font(.manrope(14))
                    .foregroundStyle(Color.red)
            }
            HStack(spacing: 12) {
                Button(guardando ? "Guardando…" : "Guardar") { guardar() }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.onAccent)
                    .padding(.horizontal, 22)
                    .frame(height: 44)
                    .background(KipColor.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(guardando)
                Button("Cancelar") { alCerrarEditor() }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .disabled(guardando)
            }
        }
        .padding(.leading, 52)
        .padding(.trailing, 16)
        .padding(.top, 6)
    }

    private func guardar() {
        // Validacion local de la Android, con sus textos exactos.
        func numero(_ texto: String) -> Double? {
            let limpio = texto.replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: ".")
            if limpio.isEmpty { return nil }
            return Double(limpio)
        }
        let aprVacio = aprTexto.trimmingCharacters(in: .whitespaces).isEmpty
        let minVacio = minimoTexto.trimmingCharacters(in: .whitespaces).isEmpty
        let diaVacio = diaTexto.trimmingCharacters(in: .whitespaces).isEmpty
        if aprVacio && minVacio && diaVacio {
            errorEditor = "Escribe al menos un dato."
            return
        }
        var apr: Double? = nil
        if !aprVacio {
            guard let valor = numero(aprTexto), valor >= 0, valor <= 100 else {
                errorEditor = "El interés (APR) debe ser un número entre 0 y 100."
                return
            }
            apr = valor
        }
        var minimo: Double? = nil
        if !minVacio {
            guard let valor = numero(minimoTexto), valor >= 0 else {
                errorEditor = "El pago mínimo debe ser un número válido."
                return
            }
            minimo = valor
        }
        var dia: Int? = nil
        if !diaVacio {
            guard let valor = Int(diaTexto.trimmingCharacters(in: .whitespaces)), (1...31).contains(valor) else {
                errorEditor = "El día de vencimiento va del 1 al 31."
                return
            }
            dia = valor
        }
        errorEditor = nil
        guardando = true
        // Las tres claves viajan siempre: un nil = NSNull borra el override.
        let cuerpo: [String: Any] = ["apr": apr ?? NSNull(),
                                      "pago_minimo": minimo ?? NSNull(),
                                      "dia_vencimiento": dia ?? NSNull()]
        Task {
            do {
                _ = try await Api.guardarDatosDeuda(id: deuda.id, cuerpo: cuerpo)
                guardando = false
                alCerrarEditor()
                alGuardar()
            } catch let e as ApiError {
                guardando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorEditor = e.errorDescription ?? "No se pudieron guardar los datos."
            } catch {
                guardando = false
                errorEditor = "No se pudieron guardar los datos."
            }
        }
    }
}

// MARK: - Simulador

struct TarjetaSimuladorDeudas: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: DeudasModelo

    var body: some View {
        KipCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Simula un cambio")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Prueba otro abono u otra estrategia. Si te gusta el resultado, guárdalo como tu plan.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text("Abono extra al mes: \(dinero(modelo.extraSimulacion))")
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Slider(value: Binding(get: { modelo.extraSimulacion }, set: { nuevo in
                    modelo.extraSimulacion = (nuevo / 25).rounded() * 25
                    modelo.programarSimulacion()
                }), in: 0...1000, step: 25)
                .tint(KipColor.accent)
                Text("Estrategia")
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                HStack(spacing: 8) {
                    ForEach(modelo.estrategiasDisponibles, id: \.clave) { estrategia in
                        let elegida = modelo.estrategiaSimulacion == estrategia.clave
                        Button(estrategia.etiqueta) {
                            modelo.estrategiaSimulacion = estrategia.clave
                            modelo.programarSimulacion()
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
                if modelo.simulando {
                    HStack(spacing: 8) {
                        ProgressView().tint(KipColor.accent).controlSize(.small)
                        Text("Calculando…")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                }
                if modelo.simulacion != nil {
                    Button {
                        Task { await modelo.guardarPlan() }
                    } label: {
                        Group {
                            if modelo.guardandoPlan {
                                ProgressView().tint(KipColor.onAccent)
                            } else {
                                Text("Quedarme con este plan").font(.manrope(16, weight: .bold))
                            }
                        }
                        .foregroundStyle(KipColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(KipColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(modelo.guardandoPlan || modelo.simulando)
                    Button("Volver a mi plan") { modelo.volverAMiPlan() }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if modelo.planGuardado {
                    Text("Tu plan quedó guardado. La tarjeta de arriba ya trabaja con estos números.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.text(scheme))
                }
                if let error = modelo.errorGuardarPlan {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                }
                if let error = modelo.errorSimulacion {
                    Text(error)
                        .font(.manrope(14))
                        .foregroundStyle(Color.red)
                }
                if let sim = modelo.simulacion {
                    Divider().background(KipColor.border(scheme))
                    resultado(sim)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func resultado(_ sim: SimulacionDeudas) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Con este cambio")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text("Libre de deudas en: \(sim.fechaLibertadTexto ?? "sin fecha con estos pagos")")
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
            if let presupuesto = sim.presupuestoMensualTexto {
                Text("Pagarías \(presupuesto) al mes")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            if let interes = sim.interesTotalTexto {
                Text("Intereses por pagar: \(interes)")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            if !sim.sinLiquidar.isEmpty {
                Text("Ojo: con este plan no se liquidan: \(sim.sinLiquidar.map { $0.textoVisible }.joined(separator: ", ")).")
                    .font(.manrope(14))
                    .foregroundStyle(Color.red)
            }
            if let comp = sim.comparacion {
                ForEach(frasesComparacion(comp), id: \.self) { frase in
                    Text(frase)
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.text(scheme))
                }
            }
        }
    }

    /// Las frases de comparacion contra el plan vigente, con sus
    /// singulares/plurales exactos de la Android.
    private func frasesComparacion(_ comp: ComparacionSimulacion) -> [String] {
        var frases: [String] = []
        if let dif = comp.mesesDiferencia {
            if dif > 0 {
                frases.append(dif == 1 ? "Saldrías 1 mes antes que con tu plan." : "Saldrías \(dif) meses antes que con tu plan.")
            } else if dif < 0 {
                let n = -dif
                frases.append(n == 1 ? "Tardarías 1 mes más que con tu plan." : "Tardarías \(n) meses más que con tu plan.")
            }
        }
        if let dias = comp.diasAdelantados, dias > 0, comp.mesesDiferencia == nil || comp.mesesDiferencia == 0 {
            frases.append("Saldrías \(dias) días antes que con tu plan.")
        }
        if let ahorrado = comp.interesAhorrado, let texto = comp.interesAhorradoTexto {
            if ahorrado > 0 {
                frases.append("Te ahorrarías \(texto) en intereses.")
            } else if ahorrado < 0 {
                frases.append("Pagarías \(texto) más en intereses.")
            }
        }
        return frases
    }
}
