import SwiftUI

// La pantalla Gastos (GastosScreen.kt de la Android): pastillas de
// periodo, barras ingreso/gasto por mes, tarjeta resumen, presupuesto,
// la dona de categorias en dos pasos, frecuentes, mayores, intereses,
// sin categorizar y no-es-gasto. El detalle de categoria vive aparte.

@MainActor
final class GastosModelo: ObservableObject {
    @Published var datos: GastosRespuesta? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var pastilla = "mes"
    @Published var incluirServicios = true
    @Published var seleccionDona: String? = nil

    private var tarea: Task<Void, Never>? = nil

    func cargar() {
        tarea?.cancel()
        cargando = true
        errorTexto = nil
        let pastillaActual = pastilla
        let servicios = incluirServicios
        tarea = Task {
            do {
                let r = try await Api.gastos(query: Self.query(pastilla: pastillaActual, servicios: servicios))
                if Task.isCancelled { return }
                datos = r
                seleccionDona = nil
                cargando = false
            } catch let e as ApiError {
                if Task.isCancelled { return }
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorTexto = e.errorDescription
                cargando = false
            } catch {
                if Task.isCancelled { return }
                errorTexto = "Algo salió mal. Intenta de nuevo."
                cargando = false
            }
        }
    }

    func elegirMes(_ mes: String) {
        pastilla = "personalizado:\(mes)"
        cargar()
    }

    static func query(pastilla: String, servicios: Bool) -> [(String, String)] {
        var q: [(String, String)] = [("incluir_servicios", servicios ? "1" : "0")]
        if pastilla.hasPrefix("personalizado:") {
            let mes = String(pastilla.dropFirst("personalizado:".count))
            q.append(("periodo", "personalizado"))
            q.append(("desde", "\(mes)-01"))
            q.append(("hasta", finDeMes(mes)))
        } else if pastilla == "mes" {
            q.append(("periodo", "mes"))
        } else {
            q.append(("periodo", "personalizado"))
            let rango = rangoDePastilla(pastilla)
            q.append(("desde", rango.0))
            q.append(("hasta", rango.1))
        }
        return q
    }

    /// El rango de las pastillas Semana/Trimestre/Ano, como la Android.
    static func rangoDePastilla(_ pastilla: String) -> (String, String) {
        let cal = Calendar(identifier: .gregorian)
        let hoy = Date()
        switch pastilla {
        case "semana":
            let semana = cal.dateInterval(of: .weekOfYear, for: hoy)!
            return (isoDeFecha(semana.start), isoDeFecha(cal.date(byAdding: .day, value: -1, to: semana.end)!))
        case "trimestre":
            let mes = cal.component(.month, from: hoy)
            let anio = cal.component(.year, from: hoy)
            let primerMes = ((mes - 1) / 3) * 3 + 1
            let inicio = "\(anio)-\(String(format: "%02d", primerMes))-01"
            var finMes = primerMes + 2
            var finAnio = anio
            if finMes > 12 { finMes -= 12; finAnio += 1 }
            let claveFin = "\(finAnio)-\(String(format: "%02d", finMes))"
            return (inicio, finDeMes(claveFin))
        case "anio":
            let anio = cal.component(.year, from: hoy)
            return ("\(anio)-01-01", "\(anio)-12-31")
        default:
            return (isoDeFecha(hoy), isoDeFecha(hoy))
        }
    }
}

/// El ultimo dia del mes "yyyy-MM" en "yyyy-MM-dd".
func finDeMes(_ mes: String) -> String {
    let partes = mes.split(separator: "-")
    guard partes.count == 2, let anio = Int(partes[0]), let m = Int(partes[1]) else { return "\(mes)-28" }
    let dias = [31, (anio % 4 == 0 && (anio % 100 != 0 || anio % 400 == 0)) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    return "\(mes)-\(String(format: "%02d", dias[m - 1]))"
}

struct GastosView: View {
    @Environment(\.colorScheme) private var scheme
    var alAbrirFicha: (Int) -> Void = { _ in }
    var alAbrirCategoria: (String) -> Void = { _ in }
    @StateObject private var modelo = GastosModelo()
    @State private var dialogoTeQuedo = false

    var body: some View {
        EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
            if let datos = modelo.datos {
                ScrollView {
                    VStack(spacing: 0) {
                        cabecera
                        if !datos.porMes.isEmpty { barrasMeses(datos) }
                        tarjetaResumen(datos)
                        if datos.presupuesto?.hayPresupuesto == true {
                            VStack(spacing: 0) {
                                TituloSeccion(texto: "Tu presupuesto")
                                BloquePresupuesto(presupuesto: datos.presupuesto!)
                            }
                        }
                        tarjetaDesglose(datos)
                        if !datos.frecuentes.isEmpty { tarjetaFrecuentes(datos) }
                        if !datos.mayores.isEmpty { tarjetaMayores(datos) }
                        if let intereses = datos.intereses, (intereses.cantidad ?? 0) > 0 {
                            SeccionPlegableGastos(titulo: "Intereses y comisiones", seccion: intereses, alAbrirFicha: alAbrirFicha)
                        }
                        if let sin = datos.sinCategorizar, (sin.cantidad ?? 0) > 0 {
                            SeccionPlegableGastos(titulo: "Sin categorizar", seccion: sin, alAbrirFicha: alAbrirFicha)
                        }
                        if let noGasto = datos.noGasto, !noGasto.filas.isEmpty {
                            tarjetaNoGasto(noGasto)
                        }
                        Color.clear.frame(height: 110)
                    }
                }
                .refreshable { modelo.cargar() }
            }
        } reintentar: {
            modelo.cargar()
        }
        .task {
            if modelo.datos == nil { modelo.cargar() }
        }
        .alert("¿Qué es «Te quedó»?", isPresented: $dialogoTeQuedo) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Es lo que entró a tus cuentas menos lo que salió en el periodo. Si es positivo, ese dinero puede ir a ahorro o a pagar deuda; si es negativo, gastaste más de lo que entró.")
        }
    }

    private var cabecera: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Gastos")
                .font(.manrope(20, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([("semana", "Semana"), ("mes", "Mes"), ("trimestre", "Trimestre"), ("anio", "Año")], id: \.0) { pastilla in
                        let elegida = modelo.pastilla == pastilla.0
                        Button(pastilla.1) {
                            modelo.pastilla = pastilla.0
                            modelo.cargar()
                        }
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(elegida ? KipColor.accent : KipColor.card(scheme))
                        .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func barrasMeses(_ datos: GastosRespuesta) -> some View {
        let maximo = max(datos.porMes.map { max($0.ingreso ?? 0, $0.total ?? 0) }.max() ?? 0, 0.01)
        let mesElegido: String? = datos.periodo == "personalizado" ? String(datos.desde.prefix(7)) : datos.porMes.first { $0.esActual == true }?.mes
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(datos.porMes.enumerated()), id: \.offset) { _, mes in
                    let elegido = mes.mes == mesElegido
                    Button {
                        if let clave = mes.mes { modelo.elegirMes(clave) }
                    } label: {
                        VStack(spacing: 4) {
                            HStack(alignment: .bottom, spacing: 3) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(KipColor.gradientEnd)
                                    .frame(width: 13, height: 6 + 78 * CGFloat((mes.ingreso ?? 0) / maximo))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(KipColor.textSecondary(scheme))
                                    .frame(width: 13, height: 6 + 78 * CGFloat((mes.total ?? 0) / maximo))
                            }
                            .frame(height: 84, alignment: .bottom)
                            .opacity(elegido ? 1 : 0.45)
                            Text(String((mes.etiqueta ?? "").prefix(3)))
                                .font(.manrope(12, weight: .semibold))
                                .foregroundStyle(elegido ? KipColor.text(scheme) : KipColor.textSecondary(scheme))
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(elegido ? KipColor.elevated(scheme).opacity(0.5) : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(elegido ? KipColor.accent : Color.clear, lineWidth: 1.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            HStack(spacing: 16) {
                leyenda(color: KipColor.gradientEnd, texto: "Ingreso")
                leyenda(color: KipColor.textSecondary(scheme), texto: "Gasto")
                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 4)
    }

    private func leyenda(color: Color, texto: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
            Text(texto)
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
        }
    }

    private func tarjetaResumen(_ datos: GastosRespuesta) -> some View {
        KipCard {
            VStack(spacing: 0) {
                filaResumen(simbolo: "arrow.down.circle.fill", color: KipColor.gradientEnd, etiqueta: "Entró", valor: datos.ingresoTexto)
                Divider().background(KipColor.border(scheme)).padding(.vertical, 10)
                filaResumen(simbolo: "arrow.up.circle.fill", color: KipColor.textSecondary(scheme), etiqueta: "Salió", valor: datos.totalTexto)
                Divider().background(KipColor.border(scheme)).padding(.vertical, 10)
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: "wallet.pass.fill", color: KipColor.accent, tamano: 34)
                    Text("Te quedó")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    Text(datos.netoTexto)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(datos.neto < 0 ? Color.red : KipColor.text(scheme))
                    Button { dialogoTeQuedo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .buttonStyle(.plain)
                }
                if let frase = datos.netoFrase, !frase.isEmpty {
                    Text(frase)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 10)
                }
                if let cambio = datos.cambioTotalPct, let previo = datos.totalPrevioTexto {
                    Text("El gasto \(textoCambioLegible(pct: cambio, direccion: nil)) que el periodo anterior (\(previo)).")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func filaResumen(simbolo: String, color: Color, etiqueta: String, valor: String) -> some View {
        HStack(spacing: 12) {
            CirculoIcono(simbolo: simbolo, color: color, tamano: 34)
            Text(etiqueta)
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            Text(valor)
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
        }
    }

    private func tarjetaDesglose(_ datos: GastosRespuesta) -> some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Desglose")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                HStack(spacing: 8) {
                    Text("Categorías")
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(KipColor.accent)
                        .clipShape(Capsule())
                    Text("Etiquetas · pronto")
                        .font(.manrope(14, weight: .bold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(KipColor.elevated(scheme))
                        .clipShape(Capsule())
                        .opacity(0.6)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                HStack {
                    Text("Incluir servicios")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Spacer()
                    KipInterruptor(activo: Binding(get: { modelo.incluirServicios }, set: { nuevo in
                        modelo.incluirServicios = nuevo
                        modelo.cargar()
                    }))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                DonaGastos(categorias: datos.categorias, total: datos.total, totalTexto: datos.totalTexto,
                           seleccionada: modelo.seleccionDona) { clave in
                    modelo.seleccionDona = clave
                } alCentro: {
                    if let clave = modelo.seleccionDona { alAbrirCategoria(clave) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                if datos.categorias.isEmpty {
                    Text("No hay gastos en este periodo.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(16)
                } else {
                    ForEach(datos.categorias) { categoria in
                        Button { alAbrirCategoria(categoria.clave) } label: {
                            HStack(spacing: 12) {
                                CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                             color: colorDona(hex: categoria.color), tamano: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(categoria.nombre)
                                        .font(.manrope(16, weight: .bold))
                                        .foregroundStyle(KipColor.text(scheme))
                                    Text(subtituloCategoria(categoria))
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer()
                                Text(categoria.montoTexto)
                                    .font(.manrope(16, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(modelo.seleccionDona == categoria.clave ? colorDona(hex: categoria.color).opacity(0.10) : Color.clear)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().background(KipColor.border(scheme)).padding(.leading, 74)
                    }
                }
                Color.clear.frame(height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func subtituloCategoria(_ categoria: GastoCategoria) -> String {
        var texto = "\(porcentajeLegible(categoria.porcentaje))% del gasto"
        if let cambio = categoria.cambioPct {
            texto += " · \(textoCambioLegible(pct: cambio, direccion: categoria.cambioDireccion))"
        }
        return texto
    }

    private func tarjetaFrecuentes(_ datos: GastosRespuesta) -> some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Text("Compras frecuentes")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                ForEach(datos.frecuentes, id: \.comercio) { frecuente in
                    HStack(spacing: 12) {
                        CirculoComercio(nombre: frecuente.comercio, tamano: 42, logoUrl: frecuente.logoUrl)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(frecuente.comercio)
                                .font(.manrope(16, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("\(frecuente.veces ?? 0) veces · Promedio \(frecuente.promedioTexto ?? "")")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer()
                        Text(frecuente.totalTexto ?? "")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    Divider().background(KipColor.border(scheme)).padding(.leading, 70)
                }
                Color.clear.frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tarjetaMayores(_ datos: GastosRespuesta) -> some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Text("Compras mayores")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                ForEach(datos.mayores) { fila in
                    FilaBreveView(fila: fila) { alAbrirFicha(fila.id) }
                    Divider().background(KipColor.border(scheme)).padding(.leading, 70)
                }
                Color.clear.frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func tarjetaNoGasto(_ noGasto: NoGasto) -> some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Text("No es gasto")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                ForEach(noGasto.filas) { fila in
                    FilaBreveView(fila: fila) { alAbrirFicha(fila.id) }
                    Divider().background(KipColor.border(scheme)).padding(.leading, 70)
                }
                Color.clear.frame(height: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// "subió 12,5%" / "bajó 3%" (textoCambio de la Android).
func textoCambioLegible(pct: Double, direccion: String?) -> String {
    let dir = direccion ?? (pct >= 0 ? "subio" : "bajo")
    let verbo = dir == "bajo" ? "bajó" : "subió"
    return "\(verbo) \(porcentajeLegible(abs(pct)))%"
}

/// El color de la dona: el hex del servidor o el acento si no parsea
/// (colorHex de la Android para Gastos).
func colorDona(hex: String?) -> Color {
    guard let hex = hex else { return KipColor.accent }
    let limpio = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
    if limpio.count == 6, limpio.allSatisfy({ $0.isHexDigit }) {
        return Color(hexCadena: limpio)
    }
    return KipColor.accent
}

/// La fila breve de Gastos (mayores, intereses, sin categorizar, no-gasto).
struct FilaBreveView: View {
    @Environment(\.colorScheme) private var scheme
    let fila: FilaBreve
    var alTocar: () -> Void = {}

    var body: some View {
        Button(action: alTocar) {
            HStack(spacing: 12) {
                CirculoComercio(nombre: fila.comercio, tamano: 42, logoUrl: fila.logoUrl)
                VStack(alignment: .leading, spacing: 2) {
                    Text(fila.comercio)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(fechaCorta(fila.fecha))
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        if let motivo = fila.motivo {
                            ChipSuave(texto: textoMotivo(motivo), color: KipPastel.teal, compacto: true)
                        }
                    }
                }
                Spacer()
                Text(fila.montoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(fila.id <= 0)
    }

    private func textoMotivo(_ motivo: String) -> String {
        switch motivo {
        case "interno": return "Interno"
        case "transferencia": return "Transferencia"
        case "reembolso": return "Reembolso"
        default: return motivo
        }
    }
}

/// Una seccion plegable de Gastos (Intereses / Sin categorizar).
struct SeccionPlegableGastos: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let seccion: SeccionBreve
    var alAbrirFicha: (Int) -> Void = { _ in }
    @State private var abierta = false

    var body: some View {
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                Button { abierta.toggle() } label: {
                    HStack {
                        Text(titulo)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer()
                        Text(seccion.totalTexto ?? "")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Image(systemName: abierta ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if abierta {
                    ForEach(seccion.filas) { fila in
                        FilaBreveView(fila: fila) { alAbrirFicha(fila.id) }
                        Divider().background(KipColor.border(scheme)).padding(.leading, 70)
                    }
                    Color.clear.frame(height: 6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// La dona de Gastos en dos pasos (decision de Jesus): tocar un arco
/// selecciona la categoria y su resumen va al centro; tocar el centro
/// abre su detalle.
struct DonaGastos: View {
    @Environment(\.colorScheme) private var scheme
    let categorias: [GastoCategoria]
    let total: Double
    let totalTexto: String
    let seleccionada: String?
    var alSeleccionar: (String) -> Void = { _ in }
    var alCentro: () -> Void = {}

    var body: some View {
        GeometryReader { geo in
            let lado = geo.size.width
            let centro = CGPoint(x: lado / 2, y: lado / 2)
            let radio = lado / 2 - 30
            let grosor = (radio * 2) * 0.055
            ZStack {
                Canvas { contexto, _ in
                    if categorias.isEmpty || total <= 0 {
                        contexto.stroke(
                            Path(ellipseIn: CGRect(x: centro.x - radio, y: centro.y - radio, width: radio * 2, height: radio * 2)),
                            with: .color(KipColor.elevated(scheme)), style: StrokeStyle(lineWidth: grosor))
                    } else {
                        var acumulado = -90.0
                        for categoria in categorias {
                            let barrido = categoria.monto / total * 360
                            let inicio = acumulado + 0.8
                            let fin = acumulado + barrido - 0.8
                            if fin > inicio {
                                var arco = Path()
                                arco.addArc(center: centro, radius: radio, startAngle: .degrees(inicio), endAngle: .degrees(fin), clockwise: false)
                                contexto.stroke(arco, with: .color(colorDona(hex: categoria.color)), style: StrokeStyle(lineWidth: grosor, lineCap: .butt))
                            }
                            acumulado += barrido
                        }
                    }
                }
                ForEach(categoriasConAngulo, id: \.categoria.clave) { entrada in
                    let angulo = entrada.angulo * Double.pi / 180
                    let rIcono = radio + grosor / 2 + 15
                    CirculoIcono(simbolo: iconoDeCategoria(clave: entrada.categoria.clave, icono: entrada.categoria.icono),
                                 color: colorDona(hex: entrada.categoria.color), tamano: 26)
                        .position(x: centro.x + rIcono * CGFloat(cos(angulo)), y: centro.y + rIcono * CGFloat(sin(angulo)))
                }
                centroTexto
                    .frame(width: (radio - grosor) * 1.5)
                    .position(centro)
            }
            .contentShape(Rectangle())
            .gesture(gesto(lado: lado, radio: radio, grosor: grosor))
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var categoriasConAngulo: [(categoria: GastoCategoria, angulo: Double)] {
        guard total > 0 else { return [] }
        var acumulado = -90.0
        var resultado: [(GastoCategoria, Double)] = []
        for categoria in categorias {
            let barrido = categoria.monto / total * 360
            if barrido >= 15 {
                resultado.append((categoria, acumulado + barrido / 2))
            }
            acumulado += barrido
        }
        return resultado
    }

    @ViewBuilder
    private var centroTexto: some View {
        if let clave = seleccionada, let categoria = categorias.first(where: { $0.clave == clave }) {
            VStack(spacing: 2) {
                Text(categoria.nombre)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(categoria.montoTexto)
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("\(porcentajeLegible(categoria.porcentaje))% del gasto")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text("Toca el centro para ver su detalle")
                    .font(.manrope(11, weight: .heavy))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        } else {
            VStack(spacing: 2) {
                Text(totalTexto)
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("de gasto")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
    }

    private func gesto(lado: CGFloat, radio: CGFloat, grosor: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { valor in
                let centro = CGPoint(x: lado / 2, y: lado / 2)
                let dx = valor.location.x - centro.x
                let dy = valor.location.y - centro.y
                let distancia = sqrt(dx * dx + dy * dy)
                if distancia < radio - grosor {
                    alCentro()
                    return
                }
                guard distancia <= radio + grosor + (lado / 2 - radio) * 0.7, total > 0 else { return }
                var angulo = atan2(Double(dy), Double(dx)) * 180 / Double.pi + 90
                if angulo < 0 { angulo += 360 }
                var acumulado = 0.0
                for categoria in categorias {
                    let barrido = categoria.monto / total * 360
                    if angulo >= acumulado && angulo < acumulado + barrido {
                        alSeleccionar(categoria.clave)
                        return
                    }
                    acumulado += barrido
                }
            }
    }
}
