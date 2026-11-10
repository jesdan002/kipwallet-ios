import SwiftUI
import UIKit

// Componentes compartidos de la app: los mismos mapas de color e icono
// de la Android (KipPasteles, CategoriaIcono.kt) para que una categoria
// o un comercio se vean IDENTICOS en las dos plataformas.

extension Color {
    init(hexCadena: String) {
        var limpio = hexCadena.trimmingCharacters(in: .whitespaces)
        if limpio.hasPrefix("#") { limpio.removeFirst() }
        if limpio.count == 6, let valor = UInt32(limpio, radix: 16) {
            self.init(hex: valor)
        } else {
            self = .gray
        }
    }
}

/// Los pasteles de la familia (KipPasteles de la Android, valores exactos).
enum KipPastel {
    static let verde = Color(hex: 0x2FA36B)
    static let azul = Color(hex: 0x3E7CB1)
    static let naranja = Color(hex: 0xD97B29)
    static let morado = Color(hex: 0x7C5CBF)
    static let rosa = Color(hex: 0xD45D8A)
    static let teal = Color(hex: 0x2A9D8F)
    static let ambar = Color(hex: 0xC08A00)
    static let rojo = Color(hex: 0xC94F4F)
    static let indigo = Color(hex: 0x5B6ABF)
    static let cafe = Color(hex: 0x9A6B4F)

    static let todos: [Color] = [verde, azul, naranja, morado, rosa, teal, ambar, indigo, cafe, rojo]

    /// Color estable para una semilla: el hash de Java/Kotlin que usa la
    /// Android (h = 31*h + c sobre UTF-16, con abs al final).
    static func para(_ semilla: String) -> Color {
        if semilla.trimmingCharacters(in: .whitespaces).isEmpty { return verde }
        var h: Int32 = 0
        for unidad in semilla.lowercased().utf16 {
            h = 31 &* h &+ Int32(unidad)
        }
        let indice = Int(abs(Int(h)) % todos.count)
        return todos[indice]
    }
}

extension Color {
    /// Mezcla lineal hacia otro color (el lerp de la Android), para el
    /// degradado del bloque de ingresos del flujo.
    func blend(hacia otro: Color, fraccion: CGFloat) -> Color {
        let a = UIColor(self)
        let b = UIColor(otro)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double(r1 + (r2 - r1) * fraccion),
                     green: Double(g1 + (g2 - g1) * fraccion),
                     blue: Double(b1 + (b2 - b1) * fraccion),
                     opacity: Double(a1 + (a2 - a1) * fraccion))
    }
}

/// El color pleno de una categoria: el hex que manda el servidor o,
/// si no viene, el de su familia (colorDeCategoria de la Android).
func colorDeCategoria(hex: String?, clave: String?) -> Color {
    if let hex = hex {
        let limpio = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if limpio.count == 6, limpio.allSatisfy({ $0.isHexDigit }) {
            return Color(hexCadena: limpio)
        }
    }
    let c = (clave ?? "").lowercased()
    func tiene(_ claves: [String]) -> Bool { claves.contains { c.contains($0) } }
    if tiene(["transfer"]) { return KipPastel.indigo }
    if tiene(["ingreso", "income", "nomina", "payroll", "salario"]) { return KipPastel.verde }
    if tiene(["super", "grocer", "despensa", "mercado"]) { return KipPastel.naranja }
    if tiene(["restaur", "comida", "food", "drink"]) { return KipPastel.rosa }
    if tiene(["cafe", "coffee"]) { return KipPastel.cafe }
    if tiene(["gasolin", "gas"]) { return KipPastel.ambar }
    if tiene(["transport", "auto", "car", "taxi", "uber"]) { return KipPastel.azul }
    if tiene(["viaje", "travel", "vuelo", "hotel"]) { return KipPastel.teal }
    if tiene(["vivienda", "renta", "rent", "hogar", "casa"]) { return KipPastel.morado }
    if tiene(["servicio", "utilit", "luz", "agua", "electric"]) { return KipPastel.indigo }
    if tiene(["internet", "telefono", "phone", "wifi"]) { return KipPastel.azul }
    if tiene(["salud", "health", "medic", "doctor", "farmacia", "pharmacy"]) { return KipPastel.rojo }
    if tiene(["entreten", "entertainment", "cine", "juego", "musica", "music"]) { return KipPastel.morado }
    if tiene(["suscrip", "subscri", "streaming"]) { return KipPastel.rosa }
    if tiene(["compra", "shop", "retail", "tienda"]) { return KipPastel.naranja }
    if tiene(["ropa", "cloth"]) { return KipPastel.rosa }
    if tiene(["educac", "school", "colegiatura"]) { return KipPastel.azul }
    if tiene(["libro", "book"]) { return KipPastel.teal }
    if tiene(["mascota", "pet"]) { return KipPastel.ambar }
    if tiene(["regalo", "gift"]) { return KipPastel.rosa }
    if tiene(["banco", "bank", "comision", "fee"]) { return KipPastel.indigo }
    if tiene(["tarjeta", "credit", "deuda", "loan", "prestamo"]) { return KipPastel.indigo }
    if tiene(["ahorro", "saving"]) { return KipPastel.verde }
    if tiene(["inversion", "invest"]) { return KipPastel.verde }
    if tiene(["trabajo", "work", "oficina"]) { return KipPastel.azul }
    if tiene(["ejercicio", "gym", "deporte", "sport"]) { return KipPastel.teal }
    if tiene(["belleza", "spa", "personal"]) { return KipPastel.rosa }
    if tiene(["hijo", "child", "bebe"]) { return KipPastel.ambar }
    if tiene(["reparac", "mantenimiento", "repair"]) { return KipPastel.cafe }
    if tiene(["local", "negocio"]) { return KipPastel.naranja }
    if tiene(["impuesto", "tax", "recibo"]) { return KipPastel.indigo }
    if tiene(["donacion", "donation"]) { return KipPastel.rosa }
    if tiene(["legal"]) { return KipPastel.indigo }
    if tiene(["seguro", "insurance"]) { return KipPastel.azul }
    if tiene(["software", "tecnolog"]) { return KipPastel.azul }
    if tiene(["familiar"]) { return KipPastel.ambar }
    if tiene(["efectivo", "cash"]) { return KipPastel.verde }
    return KipPastel.azul
}

/// El icono SF Symbol de una categoria: primero el nombre que manda el
/// servidor (los 60 elegibles) y si no, el de su familia por la clave.
func iconoDeCategoria(clave: String?, icono: String?) -> String {
    if let icono = icono, !icono.isEmpty {
        return iconoPorNombre(icono)
    }
    let c = (clave ?? "").lowercased()
    func tiene(_ claves: [String]) -> Bool { claves.contains { c.contains($0) } }
    if tiene(["transfer"]) { return "arrow.left.arrow.right" }
    if tiene(["ingreso", "income", "nomina", "payroll", "salario"]) { return "dollarsign.circle.fill" }
    if tiene(["super", "grocer", "despensa", "mercado"]) { return "cart.fill" }
    if tiene(["restaur", "comida", "food", "drink"]) { return "fork.knife" }
    if tiene(["cafe", "coffee"]) { return "cup.and.saucer.fill" }
    if tiene(["gasolin", "gas"]) { return "fuelpump.fill" }
    if tiene(["transport", "auto", "car", "taxi", "uber"]) { return "car.fill" }
    if tiene(["viaje", "travel", "vuelo", "hotel"]) { return "airplane" }
    if tiene(["vivienda", "renta", "rent", "hogar", "casa"]) { return "house.fill" }
    if tiene(["servicio", "utilit", "luz", "agua", "electric"]) { return "bolt.fill" }
    if tiene(["internet", "telefono", "phone", "wifi"]) { return "wifi" }
    if tiene(["salud", "health", "medic", "doctor"]) { return "cross.case.fill" }
    if tiene(["farmacia", "pharmacy"]) { return "pills.fill" }
    if tiene(["entreten", "entertainment", "cine", "juego"]) { return "film.fill" }
    if tiene(["musica", "music"]) { return "music.note" }
    if tiene(["suscrip", "subscri", "streaming"]) { return "rectangle.stack.fill" }
    if tiene(["compra", "shop", "retail", "tienda"]) { return "bag.fill" }
    if tiene(["ropa", "cloth"]) { return "tshirt.fill" }
    if tiene(["educac", "school", "colegiatura"]) { return "graduationcap.fill" }
    if tiene(["libro", "book"]) { return "book.fill" }
    if tiene(["mascota", "pet"]) { return "pawprint.fill" }
    if tiene(["regalo", "gift"]) { return "gift.fill" }
    if tiene(["banco", "bank", "comision", "fee"]) { return "building.columns.fill" }
    if tiene(["tarjeta", "credit", "deuda", "loan", "prestamo"]) { return "creditcard.fill" }
    if tiene(["ahorro", "saving"]) { return "banknote.fill" }
    if tiene(["inversion", "invest"]) { return "chart.line.uptrend.xyaxis" }
    if tiene(["trabajo", "work", "oficina"]) { return "briefcase.fill" }
    if tiene(["ejercicio", "gym", "deporte", "sport"]) { return "dumbbell.fill" }
    if tiene(["belleza", "spa", "personal"]) { return "sparkles" }
    if tiene(["hijo", "child", "bebe"]) { return "figure.and.child.holdinghands" }
    if tiene(["reparac", "mantenimiento", "repair"]) { return "wrench.and.screwdriver.fill" }
    if tiene(["local", "negocio"]) { return "storefront.fill" }
    if tiene(["impuesto", "tax", "recibo"]) { return "doc.text.fill" }
    if tiene(["donacion", "donation"]) { return "heart.fill" }
    if tiene(["legal"]) { return "scale.3d" }
    if tiene(["seguro", "insurance"]) { return "shield.fill" }
    if tiene(["software", "tecnolog"]) { return "cloud.fill" }
    if tiene(["familiar"]) { return "figure.and.child.holdinghands" }
    if tiene(["efectivo", "cash"]) { return "dollarsign.circle.fill" }
    return "square.grid.2x2.fill"
}

/// Los 60 nombres elegibles del servidor a su SF Symbol mas cercano.
func iconoPorNombre(_ nombre: String) -> String {
    switch nombre {
    case "etiqueta": return "tag.fill"
    case "huella": return "pawprint.fill"
    case "libro": return "book.fill"
    case "regalo": return "gift.fill"
    case "corazon": return "heart.fill"
    case "porcentaje": return "percent"
    case "balanza": return "scale.3d"
    case "escudo": return "shield.fill"
    case "maletin": return "briefcase.fill"
    case "familia": return "figure.and.child.holdinghands"
    case "telefono": return "iphone"
    case "nube": return "cloud.fill"
    case "moneda": return "dollarsign.circle.fill"
    case "musica": return "music.note"
    case "tienda": return "storefront.fill"
    case "estrella": return "star.fill"
    case "comida": return "fork.knife"
    case "carro": return "car.fill"
    case "casa": return "house.fill"
    case "salud": return "cross.case.fill"
    case "gasolina": return "fuelpump.fill"
    case "restaurante": return "fork.knife"
    case "supermercado": return "cart.fill"
    case "compras": return "bag.fill"
    case "banco": return "building.columns.fill"
    case "entretenimiento": return "film.fill"
    case "viaje": return "airplane"
    case "herramienta": return "wrench.and.screwdriver.fill"
    case "tijeras": return "scissors"
    case "engrane": return "gearshape.fill"
    case "edificio": return "building.2.fill"
    case "recibo": return "doc.text.fill"
    case "cafe": return "cup.and.saucer.fill"
    case "hamburguesa": return "takeoutbag.and.cup.and.straw.fill"
    case "alcancia": return "banknote.fill"
    case "gimnasio": return "dumbbell.fill"
    case "camiseta": return "tshirt.fill"
    case "laptop": return "laptopcomputer"
    case "audifonos": return "headphones"
    case "control": return "gamecontroller.fill"
    case "planta": return "leaf.fill"
    case "pastilla": return "pills.fill"
    case "estetoscopio": return "stethoscope"
    case "pin": return "mappin"
    case "wifi": return "wifi"
    case "camara_seguridad": return "video.fill"
    case "bebe": return "figure.and.child.holdinghands"
    case "gato": return "pawprint.fill"
    case "pez": return "fish.fill"
    case "luna": return "moon.fill"
    case "paraguas": return "umbrella.fill"
    case "camion": return "truck.box.fill"
    case "mapa": return "map.fill"
    case "diamante": return "diamond.fill"
    case "camara": return "camera.fill"
    case "avion": return "airplane"
    case "maleta": return "suitcase.fill"
    case "sombrero": return "graduationcap.fill"
    case "papas": return "takeoutbag.and.cup.and.straw.fill"
    case "barco": return "ferry.fill"
    default: return "tag.fill"
    }
}

/// El icono y el color de un grupo de cuentas por su clave (los de la Android).
func iconoGrupoCuentas(_ clave: String?) -> String {
    switch clave {
    case "tarjetas": return "creditcard.fill"
    case "efectivo_neto": return "dollarsign.circle.fill"
    case "ahorros": return "banknote.fill"
    case "inversiones": return "chart.line.uptrend.xyaxis"
    case "prestamos": return "dollarsign.circle.fill"
    default: return "building.columns.fill"
    }
}

func colorGrupoCuentas(_ clave: String?) -> Color {
    switch clave {
    case "tarjetas": return KipPastel.indigo
    case "efectivo_neto": return KipPastel.verde
    case "ahorros": return KipPastel.teal
    case "inversiones": return KipPastel.morado
    case "prestamos": return KipPastel.ambar
    default: return KipPastel.azul
    }
}

func iconoTipoCuenta(_ tipo: String) -> String {
    switch tipo.lowercased() {
    case "credit": return "creditcard.fill"
    case "loan": return "dollarsign.circle.fill"
    case "investment": return "chart.line.uptrend.xyaxis"
    case "depository": return "building.columns.fill"
    default: return "wallet.pass.fill"
    }
}

func colorTipoCuenta(_ tipo: String) -> Color {
    switch tipo.lowercased() {
    case "credit": return KipPastel.indigo
    case "loan": return KipPastel.ambar
    case "investment": return KipPastel.verde
    case "depository": return KipPastel.azul
    default: return KipPastel.azul
    }
}

// MARK: - Formato (las mismas reglas de Formato.kt)

private let mesesLargos = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                           "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

func parseFecha(_ iso: String) -> Date? {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: String(iso.prefix(10)))
}

/// "2026-11-08" -> "8 de noviembre" (sin ano, como la Android).
func fechaLegible(_ iso: String) -> String {
    guard let fecha = parseFecha(iso) else { return iso }
    let cal = Calendar.current
    return "\(cal.component(.day, from: fecha)) de \(mesesLargos[cal.component(.month, from: fecha) - 1])"
}

/// "Hoy", "Ayer" o la fecha en palabras.
func fechaPalabras(_ iso: String) -> String {
    guard let fecha = parseFecha(iso) else { return iso }
    let cal = Calendar.current
    if cal.isDateInToday(fecha) { return "Hoy" }
    if cal.isDateInYesterday(fecha) { return "Ayer" }
    return fechaLegible(iso)
}

/// "martes, 10 de noviembre" — el subtitulo de la cabecera del Panel.
func fechaHoyPalabras() -> String {
    let dias = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    let cal = Calendar.current
    let hoy = Date()
    let diaSemana = dias[cal.component(.weekday, from: hoy) - 1]
    return "\(diaSemana), \(cal.component(.day, from: hoy)) de \(mesesLargos[cal.component(.month, from: hoy) - 1])"
}

/// "25 sep" — dia y mes abreviado, sin "de" (fechaCorta de la Android).
func fechaCorta(_ iso: String) -> String {
    let meses = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    guard let fecha = parseFecha(iso) else { return iso }
    let cal = Calendar.current
    return "\(cal.component(.day, from: fecha)) \(meses[cal.component(.month, from: fecha) - 1])"
}

/// "$1,744.74" — el mismo formato que el servidor usa en sus textos.
func dinero(_ valor: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = Locale(identifier: "en_US")
    return f.string(from: NSNumber(value: valor)) ?? "$\(valor)"
}

/// "12.5" -> "12.5" sin decimales sobrantes (porcentajeLegible de la Android).
func porcentajeLegible(_ valor: Double) -> String {
    if valor == valor.rounded() { return String(Int(valor)) }
    return String(format: "%.1f", valor)
}

/// El saludo segun la hora, como la cabecera de la Android.
func saludoSegunHora() -> String {
    switch Calendar.current.component(.hour, from: Date()) {
    case 5...11: return "Buenos días"
    case 12...18: return "Buenas tardes"
    default: return "Buenas noches"
    }
}

/// Texto de cercania para los proximos cobros.
func textoDias(_ dias: Int) -> String {
    if dias <= 0 { return "hoy" }
    if dias == 1 { return "mañana" }
    return "en \(dias) días"
}

// MARK: - Piezas visuales

struct KipCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TituloSeccion: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var derecha: String? = nil

    var body: some View {
        HStack {
            Text(texto.uppercased())
                .font(.manrope(12, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Spacer()
            if let derecha = derecha {
                Text(derecha)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.gradientEnd)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }
}

struct CirculoIcono: View {
    let simbolo: String
    let color: Color
    var tamano: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.16))
            Image(systemName: simbolo)
                .font(.system(size: tamano * 0.48, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: tamano, height: tamano)
    }
}

/// El circulo de un comercio: su logo si carga, o su inicial en su
/// color pastel estable (CirculoComercio de la Android).
struct CirculoComercio: View {
    let nombre: String
    var tamano: CGFloat = 42
    var logoUrl: String? = nil
    @State private var fallo = false

    var body: some View {
        if let urlCadena = logoUrl, let url = URL(string: urlCadena), !fallo {
            AsyncImage(url: url) { fase in
                switch fase {
                case .success(let imagen):
                    ZStack {
                        Circle().fill(Color(hex: 0xF2F4F6))
                        imagen.resizable().scaledToFit().frame(width: tamano * 0.76, height: tamano * 0.76)
                    }
                    .frame(width: tamano, height: tamano)
                    .clipShape(Circle())
                case .failure:
                    inicial
                default:
                    ZStack {
                        Circle().fill(Color(hex: 0xF2F4F6))
                        ProgressView().controlSize(.small)
                    }
                    .frame(width: tamano, height: tamano)
                }
            }
        } else {
            inicial
        }
    }

    private var inicial: some View {
        let color = KipPastel.para(nombre)
        return ZStack {
            Circle().fill(color.opacity(0.16))
            Text(nombre.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: tamano, height: tamano)
    }
}

/// La foto del usuario o su inicial en degradado (CirculoFoto de la Android).
struct CirculoFoto: View {
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
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var inicial: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(nombre.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "K")
                .font(.manrope(18, weight: .heavy))
                .foregroundStyle(KipColor.onAccent)
        }
    }
}

/// La mini grafica de linea de las tarjetas heroe (MiniGrafica de la Android).
struct MiniGrafica: View {
    let valores: [Double]
    var referencia: Double? = nil

    var body: some View {
        Canvas { contexto, tamano in
            guard valores.count > 1 else { return }
            let maximo = max((valores + [referencia ?? 0]).max() ?? 1, 0.0001)
            let pasoX = tamano.width / CGFloat(valores.count - 1)
            func yDe(_ v: Double) -> CGFloat { tamano.height - CGFloat(v / maximo) * (tamano.height - 6) - 3 }
            if let ref = referencia, ref > 0 {
                var linea = Path()
                linea.move(to: CGPoint(x: 0, y: yDe(ref)))
                linea.addLine(to: CGPoint(x: tamano.width, y: yDe(ref)))
                contexto.stroke(linea, with: .color(.gray.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            }
            var camino = Path()
            for (i, v) in valores.enumerated() {
                let punto = CGPoint(x: CGFloat(i) * pasoX, y: yDe(v))
                if i == 0 { camino.move(to: punto) } else { camino.addLine(to: punto) }
            }
            contexto.stroke(camino, with: .color(KipColor.gradientEnd), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 44)
    }
}

/// El boton ancho estilo Rocket del Panel: pastilla de ancho completo,
/// fondo de tarjeta, borde de texto y texto del tema (nada de letra verde).
struct BotonPanelRocket: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(KipColor.card(scheme))
                .overlay(Capsule().stroke(KipColor.text(scheme), lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// La barra de progreso fina (LinearProgressIndicator de la Android).
struct BarraProgreso: View {
    let fraccion: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25))
                Capsule().fill(color).frame(width: geo.size.width * min(max(fraccion, 0), 1))
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Piezas compartidas de la Fase 1

/// El chip suave de la casa: pastilla con el color al 14 % y el texto en
/// el color pleno (ChipSuave de la Android).
struct ChipSuave: View {
    let texto: String
    let color: Color
    var compacto = false

    var body: some View {
        Text(texto)
            .font(.manrope(compacto ? 11 : 12, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, compacto ? 7 : 10)
            .padding(.vertical, compacto ? 2 : 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// El interruptor de la casa (KipSwitch de la Android): encendido en
/// verde Kip, apagado en los tonos del tema.
struct KipInterruptor: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var activo: Bool

    var body: some View {
        Button {
            activo.toggle()
        } label: {
            ZStack(alignment: activo ? .trailing : .leading) {
                Capsule()
                    .fill(activo ? KipColor.accent : KipColor.elevated(scheme))
                    .overlay(Capsule().stroke(activo ? KipColor.accent : KipColor.border(scheme), lineWidth: 1))
                    .frame(width: 52, height: 32)
                Circle()
                    .fill(activo ? KipColor.onAccent : KipColor.textSecondary(scheme))
                    .frame(width: 24, height: 24)
                    .padding(4)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: activo)
    }
}

/// Estados de carga/error iguales en todas las pantallas de la Fase 1:
/// spinner centrado mientras no hay datos; si la carga falla sin datos,
/// el texto del error y el boton de reintento.
struct EstadoCarga<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let cargando: Bool
    let error: String?
    let listo: Bool
    @ViewBuilder var content: Content
    let reintentar: () -> Void

    init(cargando: Bool, error: String?, listo: Bool,
         @ViewBuilder content: () -> Content,
         reintentar: @escaping () -> Void = {}) {
        self.cargando = cargando
        self.error = error
        self.listo = listo
        self.content = content()
        self.reintentar = reintentar
    }

    var body: some View {
        if listo {
            content
        } else if cargando {
            VStack { Spacer(); ProgressView().tint(KipColor.accent); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 14) {
                Spacer()
                Text(error ?? "Algo salió mal. Intenta de nuevo.")
                    .font(.manrope(16))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KipColor.text(scheme))
                    .padding(.horizontal, 24)
                Button("Intentar de nuevo") { reintentar() }
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// La fila estandar de un movimiento (Movimientos, historial y cualquier
/// lista de la app): circulo del comercio con su distintivo de
/// recurrente, dos lineas de texto y el monto a la derecha.
struct FilaMovimiento: View {
    @Environment(\.colorScheme) private var scheme
    let mov: MovimientoFila
    var seleccionado: Bool? = nil
    var alSeleccionar: (() -> Void)? = nil
    let alTocar: () -> Void

    var body: some View {
        Button(action: alTocar) {
            HStack(spacing: 12) {
                if let sel = seleccionado {
                    Button {
                        alSeleccionar?()
                    } label: {
                        Image(systemName: sel ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(sel ? KipColor.gradientEnd : KipColor.textSecondary(scheme))
                    }
                    .buttonStyle(.plain)
                }
                ZStack(alignment: .bottomTrailing) {
                    CirculoComercio(nombre: mov.comercio, tamano: 42, logoUrl: mov.logoUrl)
                    if mov.esRecurrente {
                        ZStack {
                            Circle().fill(KipColor.gradientEnd)
                            Image(systemName: "repeat")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 17, height: 17)
                        .offset(x: 3, y: 3)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(mov.comercio)
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .lineLimit(1)
                        if mov.esInterno {
                            Image(systemName: "nosign")
                                .font(.system(size: 13))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                    }
                    Text(subtitulo)
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(mov.montoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(colorMonto)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var subtitulo: String {
        var partes: [String] = []
        if !mov.fechaTexto.isEmpty { partes.append(mov.fechaTexto) }
        if let pareja = mov.pareja, let et = pareja.etiqueta, !et.isEmpty {
            partes.append(et)
        } else if mov.esInterno {
            partes.append("Entre tus cuentas")
        }
        if mov.esManual { partes.append("Manual") }
        if mov.revisada { partes.append("Revisado") }
        return partes.joined(separator: " · ")
    }

    private var colorMonto: Color {
        if mov.esInterno { return KipColor.textSecondary(scheme) }
        if mov.monto < 0 { return KipColor.gradientEnd }
        return KipColor.text(scheme)
    }
}
