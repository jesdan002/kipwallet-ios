import SwiftUI

/// El Panel de Kipwallet iOS: el MISMO Panel de la app Android, bloque
/// por bloque y en el orden que el usuario guardo en sus preferencias:
/// cabecera con saludo, carrusel heroe de 3 tarjetas, configuracion,
/// proximos cobros, cuentas por tipo, movimientos recientes y
/// presupuesto del mes. Los textos llegan formateados del servidor.
@MainActor
final class PanelModel: ObservableObject {
    @Published var panel: Panel? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var sesionTerminada = false

    func cargar() {
        if cargando { return }
        cargando = true
        Task {
            do {
                let datos = try await Api.panel()
                panel = datos
                errorTexto = nil
                cargando = false
            } catch let falla as ApiError {
                cargando = false
                if case .sesionTerminada = falla {
                    Sesion.cerrar()
                    sesionTerminada = true
                } else if panel == nil {
                    errorTexto = falla.errorDescription
                }
            } catch {
                cargando = false
                if panel == nil { errorTexto = "Algo salió mal." }
            }
        }
    }
}

/// Las subpantallas que viven sobre las pestanas de la capsula.
enum RutaApp: Hashable {
    case ficha(Int)
    case categoria(String)
    case recurrentes
    case ajustes
    case notificaciones
}

/// La raiz ya con sesion: las 5 pestanas de la capsula y la pila de
/// subpantallas (ficha, detalle de categoria, recurrentes, ajustes y
/// notificaciones). La capsula vive fuera de la pila, visible siempre,
/// como en la Android, y el tema manual de Ajustes rige toda la app.
struct AppPrincipalView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var modelo = PanelModel()
    @State private var selected = 2
    @State private var pila: [RutaApp] = []
    @State private var sinLeer = 0
    @AppStorage("kw_modo_tema") private var modoTema = "sistema"

    var body: some View {
        Group {
            if modelo.sesionTerminada {
                RaizAccesoView()
            } else {
                ZStack {
                    KipColor.bg(scheme).ignoresSafeArea()
                    NavigationStack(path: $pila) {
                        Group {
                            switch selected {
                            case 0:
                                DeudasView()
                            case 1:
                                GastosView(alAbrirFicha: { pila.append(.ficha($0)) },
                                           alAbrirCategoria: { pila.append(.categoria($0)) })
                            case 3:
                                MovimientosView(alAbrirFicha: { pila.append(.ficha($0)) })
                            case 4:
                                MasView(alIrRecurrentes: { pila.append(.recurrentes) },
                                        alIrAjustes: { pila.append(.ajustes) })
                            default:
                                PanelView(modelo: modelo,
                                          sinLeer: sinLeer,
                                          alAbrirFicha: { pila.append(.ficha($0)) },
                                          alIrMovimientos: { selected = 3 },
                                          alIrRecurrentes: { pila.append(.recurrentes) },
                                          alIrAjustes: { pila.append(.ajustes) },
                                          alIrNotificaciones: { pila.append(.notificaciones) })
                            }
                        }
                        .navigationDestination(for: RutaApp.self) { ruta in
                            destino(ruta)
                        }
                    }
                    VStack {
                        Spacer()
                        BarraCapsula(selected: $selected)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
        .preferredColorScheme(modoTema == "claro" ? .light : (modoTema == "oscuro" ? .dark : nil))
        .onAppear {
            modelo.cargar()
            Task { await cargarSinLeer() }
        }
        .onChange(of: pila) { nueva in
            if nueva.isEmpty { Task { await cargarSinLeer() } }
        }
    }

    @ViewBuilder
    private func destino(_ ruta: RutaApp) -> some View {
        switch ruta {
        case .ficha(let id):
            FichaMovimientoView(id: id, alAbrirOtro: { pila.append(.ficha($0)) })
                .navigationBarBackButtonHidden(true)
        case .categoria(let clave):
            CategoriaDetalleView(clave: clave, alAbrirFicha: { pila.append(.ficha($0)) })
                .navigationBarBackButtonHidden(true)
        case .recurrentes:
            RecurrentesView(conVolver: true, alIrAAjustes: { pila.append(.ajustes) })
                .navigationBarBackButtonHidden(true)
        case .ajustes:
            AjustesView()
                .navigationBarBackButtonHidden(true)
        case .notificaciones:
            NotificacionesView()
                .navigationBarBackButtonHidden(true)
        }
    }

    private func cargarSinLeer() async {
        if let centro = try? await Api.notificaciones() {
            sinLeer = centro.sinLeer
        }
    }
}

struct PanelView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: PanelModel
    var sinLeer: Int = 0
    var alAbrirFicha: (Int) -> Void = { _ in }
    var alIrMovimientos: () -> Void = {}
    var alIrRecurrentes: () -> Void = {}
    var alIrAjustes: () -> Void = {}
    var alIrNotificaciones: () -> Void = {}

    var body: some View {
        Group {
            if let panel = modelo.panel {
                ScrollView {
                    VStack(spacing: 0) {
                        if modelo.cargando {
                            ProgressView()
                                .tint(KipColor.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                        }
                        CabeceraPanel(panel: panel, sinLeer: sinLeer,
                                      alNotificaciones: alIrNotificaciones,
                                      alAjustes: alIrAjustes)
                        if panel.enPausa == true {
                            KipCard {
                                Text("Tu cuenta está en pausa. Puedes ver tu información, pero algunas funciones están detenidas mientras tanto.")
                                    .font(.manrope(15))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        ForEach(panel.preferencias.orden, id: \.self) { clave in
                            if !panel.preferencias.ocultos.contains(clave) {
                                bloque(clave, panel: panel)
                            }
                        }
                        BotonPanelRocket(texto: "Personalizar mi panel") {}
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        Spacer().frame(height: 110)
                    }
                }
                .refreshable { modelo.cargar() }
            } else if modelo.cargando {
                VStack(spacing: 16) {
                    LogoMarca(tamano: 92, radio: 21)
                    ProgressView().tint(KipColor.accent)
                    Text("Cargando tu Panel…")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    LogoMarca(tamano: 92, radio: 21)
                    Text(modelo.errorTexto ?? "No se pudo cargar tu Panel. Intenta de nuevo.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    BotonPrimario(texto: "Intentar de nuevo") { modelo.cargar() }
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func bloque(_ clave: String, panel: Panel) -> some View {
        switch clave {
        case "carrusel":
            CarruselHeroe(panel: panel)
        case "flujo":
            if let sankey = panel.carrusel.sankey {
                TarjetaFlujo(sankey: sankey)
            }
        case "configuracion":
            if !panel.configuracion.completa && !panel.configuracion.pasos.isEmpty {
                BloqueConfiguracion(configuracion: panel.configuracion)
            }
        case "proximos":
            VStack(spacing: 0) {
                TituloSeccion(texto: "Próximos cobros",
                              derecha: panel.proximos.isEmpty ? nil : dinero(panel.proximos.reduce(0) { $0 + $1.monto }))
                BloqueProximos(proximos: panel.proximos, alVerTodo: alIrRecurrentes)
            }
            .contentShape(Rectangle())
            .onTapGesture { alIrRecurrentes() }
        case "cuentas":
            TarjetaCuentas(panel: panel)
        case "recientes":
            VStack(spacing: 0) {
                TituloSeccion(texto: "Movimientos recientes")
                if !panel.recientes.isEmpty {
                    TarjetaRevisaMovimientos()
                        .contentShape(Rectangle())
                        .onTapGesture { alIrMovimientos() }
                }
                KipCard(padding: 0) {
                    VStack(spacing: 0) {
                        if panel.recientes.isEmpty {
                            Text("Todavía no hay movimientos.")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        } else {
                            ForEach(Array(panel.recientes.enumerated()), id: \.offset) { indice, reciente in
                                if indice > 0 { Divider().background(KipColor.border(scheme)) }
                                FilaReciente(reciente: reciente)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if let id = reciente.id { alAbrirFicha(id) }
                                    }
                            }
                            Divider().background(KipColor.border(scheme))
                            BotonPanelRocket(texto: "Ver todos los movimientos") { alIrMovimientos() }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        case "presupuesto":
            if panel.presupuesto.hayPresupuesto == true {
                VStack(spacing: 0) {
                    TituloSeccion(texto: "Presupuesto del mes")
                    BloquePresupuesto(presupuesto: panel.presupuesto)
                }
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Cabecera

struct CabeceraPanel: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel
    var sinLeer: Int = 0
    var alNotificaciones: () -> Void = {}
    var alAjustes: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            CirculoFoto(fotoUrl: panel.fotoUrl, nombre: panel.primerNombre ?? "")
            VStack(alignment: .leading, spacing: 2) {
                Text((panel.primerNombre ?? "").isEmpty ? saludoSegunHora() : "\(saludoSegunHora()), \(panel.primerNombre ?? "")")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(fechaHoyPalabras())
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            Button { alNotificaciones() } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(KipColor.text(scheme))
                    if sinLeer > 0 {
                        Text(sinLeer > 99 ? "99" : "\(sinLeer)")
                            .font(.manrope(10, weight: .heavy))
                            .foregroundStyle(KipColor.onAccent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(KipColor.accent)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -8)
                    }
                }
                .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Button { alAjustes() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

// MARK: - Carrusel heroe

struct InfoHeroe {
    let titulo: String
    let texto: String
}

/// El carrusel heroe de 3 tarjetas con loop, como el de la Android.
struct CarruselHeroe: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel
    @State private var pagina = 1500
    @State private var info: InfoHeroe? = nil

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $pagina) {
                ForEach(0..<3000, id: \.self) { virtual in
                    tarjeta(virtual % 3)
                        .tag(virtual)
                        .padding(.horizontal, 16)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 268)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { indice in
                    Circle()
                        .fill(pagina % 3 == indice ? KipColor.gradientEnd : KipColor.border(scheme))
                        .frame(width: pagina % 3 == indice ? 8 : 6, height: pagina % 3 == indice ? 8 : 6)
                }
            }
        }
        .padding(.vertical, 8)
        .alert(item: Binding(get: { info }, set: { info = $0 })) { dato in
            Alert(title: Text(dato.titulo), message: Text(dato.texto),
                  dismissButton: .default(Text("Entendido")))
        }
    }

    @ViewBuilder
    private func tarjeta(_ indice: Int) -> some View {
        switch indice {
        case 0: TarjetaHeroeGasto(panel: panel) { info = InfoHeroe(titulo: "¿Cómo se calcula tu gasto del mes?", texto: "Sumamos todo lo que salió de tus cuentas este mes, sin contar traspasos entre tus propias cuentas. La línea punteada es tu presupuesto del mes: si la curva la cruza, ya gastaste más de lo que planeaste.") }
        case 1: TarjetaHeroePatrimonio(panel: panel) { info = InfoHeroe(titulo: "¿Cómo se calcula tu patrimonio neto?", texto: "Sumamos los saldos de todas tus cuentas conectadas y restamos el total de tus deudas. Si el número es positivo, tienes más de lo que debes. La curva se estima con tus movimientos.") }
        default: TarjetaHeroeDeudas(panel: panel) { info = InfoHeroe(titulo: "¿Cómo se calcula tu fecha de libertad?", texto: "Sumamos los saldos de tus tarjetas y préstamos. La fecha de libertad sale de simular tus pagos mes a mes con tu plan: pagas el mínimo de cada deuda y el dinero extra va a la que marca tu plan, hasta que todas quedan en cero.") }
        }
    }
}

extension InfoHeroe: Identifiable {
    var id: String { titulo }
}

/// La cascara comun de las tarjetas heroe: etiqueta y su (i) arriba,
/// el contenido al centro y la tira al pie.
struct TarjetaHeroeBase<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    let tira: String?
    let alInfo: () -> Void
    @ViewBuilder var contenido: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(etiqueta)
                        .font(.manrope(11, weight: .bold))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                    Spacer()
                    Button(action: alInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .buttonStyle(.plain)
                }
                contenido
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            Spacer(minLength: 0)
            if let tira = tira {
                Text(tira)
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(KipColor.elevated(scheme))
            }
        }
        .frame(height: 252)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct TarjetaHeroeGasto: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel
    let alInfo: () -> Void

    var body: some View {
        let gasto = panel.carrusel.gastoMes
        TarjetaHeroeBase(etiqueta: "GASTASTE ESTE MES", tira: panel.carrusel.diaPago.texto, alInfo: alInfo) {
            Text(gasto.totalTexto ?? "$0.00")
                .font(.manrope(36, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            if let cambio = gasto.cambioPct {
                let abajo = cambio <= 0
                HStack(spacing: 6) {
                    Image(systemName: abajo ? "checkmark.circle.fill" : "arrow.up.right")
                        .foregroundStyle(abajo ? KipColor.gradientEnd : Color.red)
                    Text("Vas \(gasto.diferenciaTexto ?? "") \(abajo ? "abajo" : "arriba") del mes pasado")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.top, 4)
            }
            Spacer().frame(height: 8)
            MiniGrafica(valores: gasto.serie ?? [],
                        referencia: (gasto.presupuestoTotal ?? 0) > 0 ? gasto.presupuestoTotal : nil)
        }
    }
}

struct TarjetaHeroePatrimonio: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel
    let alInfo: () -> Void

    var body: some View {
        let patrimonio = panel.carrusel.patrimonio
        TarjetaHeroeBase(etiqueta: "PATRIMONIO NETO", tira: "Ver Patrimonio", alInfo: alInfo) {
            Text(panel.patrimonioNetoTexto)
                .font(.manrope(36, weight: .heavy))
                .foregroundStyle(KipColor.text(scheme))
            if let cambio = patrimonio.cambioPct {
                let subio = cambio >= 0
                HStack(spacing: 6) {
                    Image(systemName: subio ? "arrow.up.right" : "arrow.down.right")
                        .foregroundStyle(subio ? KipColor.gradientEnd : Color.red)
                    Text("\(subio ? "Subió" : "Bajó") \(porcentajeLegible(abs(cambio)))% el último mes")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.top, 4)
            }
            Spacer().frame(height: 8)
            MiniGrafica(valores: (patrimonio.serie ?? []).map { $0.neto ?? 0 })
        }
    }
}

struct TarjetaHeroeDeudas: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel
    let alInfo: () -> Void

    var body: some View {
        let deudas = panel.deudas
        TarjetaHeroeBase(etiqueta: "SALIR DE DEUDAS", tira: "Ver mi plan", alInfo: alInfo) {
            if deudas.cantidad == 0 {
                Text("Sin deudas")
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("No tienes deudas registradas. Así se ve la libertad.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.top, 4)
            } else {
                Text(deudas.fechaLibertadTexto != nil ? "Libre en \(deudas.fechaLibertadTexto!)" : deudas.totalTexto)
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Deuda total \(deudas.totalTexto) · \(deudas.estrategiaTexto)")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.top, 4)
                Spacer().frame(height: 8)
                MiniGrafica(valores: (panel.carrusel.deudas.serie ?? []).map { $0.saldo ?? 0 })
            }
        }
    }
}

// MARK: - Flujo de tu dinero

/// El flujo del mes en su tarjeta: la MISMA estructura de la Android
/// (ronda 0.9.9, propuesta de Jesus): un solo contenedor desplazable
/// en horizontal donde el lienzo (solo dibujo) y la columna de
/// etiquetas viven separados — el dibujo jamas pinta debajo de un
/// texto y las etiquetas nunca se enciman. Con las flechas se cambia
/// de mes (hasta 11 atras), igual que en la Android.
struct TarjetaFlujo: View {
    @Environment(\.colorScheme) private var scheme
    let sankey: Sankey
    @State private var infoAbierta = false
    @State private var mesPedido: String? = nil
    @State private var flujoMes: Sankey? = nil
    @State private var sinFlujo = false
    @State private var cargandoFlujo = false
    @State private var errorFlujo: String? = nil

    private var mostrado: Sankey? { mesPedido != nil ? flujoMes : sankey }
    private var mesMostrado: String { mesPedido ?? sankey.mes ?? "" }

    var body: some View {
        let claveActual = claveMesActual()
        let claveLimite = claveMesDesplazada(claveActual, -11)
        let puedeAtras = !cargandoFlujo && mesMostrado > claveLimite
        let puedeAdelante = !cargandoFlujo && mesMostrado < claveActual
        return VStack(spacing: 0) {
            KipCard(padding: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        Text("FLUJO DE TU DINERO")
                            .font(.manrope(12, weight: .bold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Spacer()
                        Button { pedirMes(claveMesDesplazada(mesMostrado, -1)) } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(puedeAtras ? KipColor.textSecondary(scheme) : KipColor.textSecondary(scheme).opacity(0.38))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .disabled(!puedeAtras)
                        Button { pedirMes(claveMesDesplazada(mesMostrado, 1)) } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(puedeAdelante ? KipColor.textSecondary(scheme) : KipColor.textSecondary(scheme).opacity(0.38))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                        .disabled(!puedeAdelante)
                        Button { infoAbierta = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    contenido
                    if let flujo = mostrado, !cargandoFlujo, errorFlujo == nil {
                        Text(flujo.esMesActual == true
                             ? "Entraron \(flujo.ingresoTexto ?? "") en lo que va de \(flujo.mesEtiqueta ?? "")"
                             : "Entraron \(flujo.ingresoTexto ?? "") en \(flujo.mesEtiqueta ?? "")")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.text(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(KipColor.elevated(scheme))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .alert("¿Qué es el flujo de tu dinero?", isPresented: $infoAbierta) {
            Button("Entendido") {}
        } message: {
            Text("A la izquierda está todo lo que entró en el mes. A la derecha, a dónde se fue: cada franja es una categoría de gasto (o tu ahorro, si entró más de lo que salió) con su parte del total que entró. Con las flechas cambias de mes: si es el mes en curso, el flujo va corriendo con lo que ha entrado y salido hasta hoy, y el ahorro es lo que va quedando por ahora.")
        }
    }

    @ViewBuilder
    private var contenido: some View {
        if cargandoFlujo {
            ProgressView().tint(KipColor.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
        } else if let errorFlujo {
            Text(errorFlujo)
                .font(.manrope(16))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if sinFlujo {
            Text("En \(nombreMesDeClave(mesMostrado)) no entró dinero, así que no hay flujo que mostrar. Muévete a otro mes con las flechas.")
                .font(.manrope(16))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        } else if let flujo = mostrado {
            if (flujo.flujos ?? []).isEmpty {
                Text("Este mes aún no hay gasto que repartir.")
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            } else {
                DiagramaFlujo(sankey: flujo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
    }

    private func pedirMes(_ clave: String) {
        mesPedido = clave
        cargandoFlujo = true
        errorFlujo = nil
        sinFlujo = false
        Task {
            do {
                let flujo = try await Api.flujoDelMes(clave)
                flujoMes = flujo
                sinFlujo = flujo == nil
                cargandoFlujo = false
            } catch let falla as ApiError {
                if case .sesionTerminada = falla { Sesion.cerrar(); return }
                errorFlujo = falla.errorDescription
                cargandoFlujo = false
            } catch {
                errorFlujo = "Algo salió mal. Intenta de nuevo."
                cargandoFlujo = false
            }
        }
    }
}

/// El diagrama en una sola fila desplazable: a la izquierda el lienzo
/// (bloque de ingresos en degradado, franjas Bezier con degradado del
/// verde de marca al color de su categoria a 0.85 y la barra final de
/// cada categoria) y a la derecha la columna de etiquetas, fuera del
/// area de dibujo. La geometria se calcula una sola vez y manda en
/// los dos contenedores; cada etiqueta quisiera ir al centro de su
/// bloque, pero la columna le garantiza 40 de alto: jamas se enciman.
struct DiagramaFlujo: View {
    @Environment(\.colorScheme) private var scheme
    let sankey: Sankey

    var body: some View {
        let flujos = sankey.flujos ?? []
        let altoTotal: CGFloat = 280
        let anchoColumna: CGFloat = 168
        let sep: CGFloat = 40
        let mitad = sep / 2
        let totalFlujos = flujos.reduce(0.0) { $0 + ($1.monto ?? 0) }
        let sumaAlturas = altoTotal * 0.76
        let hueco: CGFloat = flujos.count > 1 ? (altoTotal - sumaAlturas) / CGFloat(flujos.count - 1) : 0
        let alturas: [CGFloat] = flujos.map { totalFlujos > 0 ? sumaAlturas * CGFloat(($0.monto ?? 0) / totalFlujos) : 0 }
        let altoIzq = alturas.reduce(0, +)
        var topsDer: [CGFloat] = []
        var yAcum: CGFloat = 0
        for h in alturas { topsDer.append(yAcum); yAcum += h + hueco }
        var centros: [CGFloat] = flujos.indices.map { topsDer[$0] + alturas[$0] / 2 }
        for i in centros.indices {
            let piso = i == 0 ? mitad : centros[i - 1] + sep
            if centros[i] < piso { centros[i] = piso }
        }
        if !centros.isEmpty {
            let techo = altoTotal - mitad
            if centros[centros.count - 1] > techo { centros[centros.count - 1] = techo }
            if centros.count > 1 {
                for i in stride(from: centros.count - 2, through: 0, by: -1) {
                    let limite = centros[i + 1] - sep
                    if centros[i] > limite { centros[i] = limite }
                }
            }
            if centros[0] < mitad {
                centros[0] = mitad
                for i in 1..<centros.count { centros[i] = centros[i - 1] + sep }
            }
        }
        let colores: [Color] = flujos.map { flujo in
            if flujo.esAhorro == true { return KipColor.accent }
            let semilla = (flujo.clave ?? "").isEmpty ? (flujo.etiqueta ?? "") : (flujo.clave ?? "")
            return KipPastel.para(semilla)
        }
        return GeometryReader { geo in
            let anchoTotal = geo.size.width * 1.6
            let anchoLienzo = anchoTotal - anchoColumna
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        LienzoFlujo(flujos: flujos, alturas: alturas, topsDer: topsDer,
                                    altoIzq: altoIzq, colores: colores, total: totalFlujos)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ingresos")
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(sankey.ingresoTexto ?? "")
                                .font(.manrope(14))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 12, y: max((altoIzq / 2) - 22, 0))
                    }
                    .frame(width: anchoLienzo, height: altoTotal)
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(flujos.enumerated()), id: \.offset) { indice, flujo in
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(flujo.etiqueta ?? "")
                                    .font(.manrope(12, weight: .semibold))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .lineLimit(1)
                                Text("\(flujo.montoTexto ?? "") · \(porcentajeLegible(flujo.pct ?? 0))%")
                                    .font(.manrope(12))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                                    .lineLimit(1)
                            }
                            .frame(width: anchoColumna - 24, alignment: .trailing)
                            .offset(x: 14, y: max(centros[indice] - 19, 0))
                        }
                    }
                    .frame(width: anchoColumna, height: altoTotal)
                }
                .frame(width: anchoTotal, height: altoTotal)
            }
        }
        .frame(height: altoTotal)
    }
}

/// El lienzo del flujo: SOLO dibujo, ningun texto vive aqui.
struct LienzoFlujo: View {
    let flujos: [SankeyFlujo]
    let alturas: [CGFloat]
    let topsDer: [CGFloat]
    let altoIzq: CGFloat
    let colores: [Color]
    let total: Double

    var body: some View {
        Canvas { contexto, tamano in
            if total <= 0 { return }
            let anchoIzqPx = tamano.width * 0.30
            let xDerPx = tamano.width - 10
            let ctrlX = anchoIzqPx + (xDerPx - anchoIzqPx) * 0.55
            let verdeProfundo = KipColor.gradientEnd.blend(hacia: .black, fraccion: 0.30)
            let gradBloque = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [verdeProfundo, KipColor.gradientEnd]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: anchoIzqPx, y: 0))
            contexto.fill(Path(CGRect(x: 0, y: 0, width: anchoIzqPx, height: altoIzq)), with: gradBloque)
            var yIzq: CGFloat = 0
            for (indice, _) in flujos.enumerated() {
                let h = alturas[indice]
                let yDer = topsDer[indice]
                var camino = Path()
                camino.move(to: CGPoint(x: anchoIzqPx, y: yIzq))
                camino.addCurve(to: CGPoint(x: xDerPx, y: yDer),
                                control1: CGPoint(x: ctrlX, y: yIzq),
                                control2: CGPoint(x: ctrlX, y: yDer))
                camino.addLine(to: CGPoint(x: xDerPx, y: yDer + h))
                camino.addCurve(to: CGPoint(x: anchoIzqPx, y: yIzq + h),
                                control1: CGPoint(x: ctrlX, y: yDer + h),
                                control2: CGPoint(x: ctrlX, y: yIzq + h))
                camino.closeSubpath()
                let gradFranja = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [KipColor.gradientEnd, colores[indice]]),
                    startPoint: CGPoint(x: anchoIzqPx, y: yIzq + h / 2),
                    endPoint: CGPoint(x: xDerPx, y: yDer + h / 2))
                contexto.drawLayer { capa in
                    capa.opacity = 0.85
                    capa.fill(camino, with: gradFranja)
                }
                contexto.fill(Path(CGRect(x: xDerPx, y: yDer, width: 10, height: max(h, 2))), with: .color(colores[indice]))
                yIzq += h
            }
        }
    }
}

/// Las claves de mes del flujo («2026-11»), como las de la Android.
private let NOMBRES_MES_FLUJO = ["enero", "febrero", "marzo", "abril", "mayo", "junio",
                                 "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]

func claveMesActual() -> String {
    let partes = Calendar.current.dateComponents([.year, .month], from: Date())
    return String(format: "%04d-%02d", partes.year ?? 2026, partes.month ?? 1)
}

func claveMesDesplazada(_ clave: String, _ delta: Int) -> String {
    let partes = clave.split(separator: "-")
    guard partes.count == 2, let anio = Int(partes[0]), let mes = Int(partes[1]) else { return clave }
    let total = anio * 12 + (mes - 1) + delta
    return String(format: "%04d-%02d", total / 12, total % 12 + 1)
}

func nombreMesDeClave(_ clave: String) -> String {
    let partes = clave.split(separator: "-")
    guard partes.count == 2, let mes = Int(partes[1]), mes >= 1, mes <= 12 else { return clave }
    return NOMBRES_MES_FLUJO[mes - 1]
}

// MARK: - Configuracion

struct BloqueConfiguracion: View {
    @Environment(\.colorScheme) private var scheme
    let configuracion: Configuracion
    @State private var expandido = true
    @State private var hechosAbiertos = false

    var body: some View {
        let pendientes = configuracion.pasos.filter { !($0.hecho ?? false) }
        let hechos = configuracion.pasos.filter { $0.hecho ?? false }
        KipCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Button { expandido.toggle() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Completa tu configuración")
                                .font(.manrope(16, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("\(configuracion.hechos) de \(configuracion.total) pasos listos")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer()
                        Image(systemName: expandido ? "chevron.up" : "chevron.down")
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                BarraProgreso(fraccion: Double(configuracion.porcentaje) / 100, color: KipColor.text(scheme))
                    .padding(.horizontal, 16)
                if expandido {
                    Spacer().frame(height: 8)
                    ForEach(pendientes) { paso in
                        FilaPaso(etiqueta: paso.etiqueta ?? "", hecho: false)
                    }
                    if !hechos.isEmpty {
                        Button { hechosAbiertos.toggle() } label: {
                            HStack {
                                Text("Hechos (\(hechos.count))")
                                    .font(.manrope(15))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                Image(systemName: hechosAbiertos ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if hechosAbiertos {
                            ForEach(hechos) { paso in
                                FilaPaso(etiqueta: paso.etiqueta ?? "", hecho: true)
                            }
                        }
                    }
                    Spacer().frame(height: 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct FilaPaso: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    let hecho: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: hecho ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(hecho ? KipColor.gradientEnd : KipColor.textSecondary(scheme))
            Text(etiqueta)
                .font(.manrope(17))
                .foregroundStyle(hecho ? KipColor.textSecondary(scheme) : KipColor.text(scheme))
            Spacer()
            if !hecho {
                Image(systemName: "chevron.right")
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Proximos cobros

struct BloqueProximos: View {
    @Environment(\.colorScheme) private var scheme
    let proximos: [Proximo]
    var alVerTodo: () -> Void = {}

    var body: some View {
        if proximos.isEmpty {
            KipCard {
                Text("No hay cobros cercanos.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(proximos) { proximo in
                        MiniTarjetaProximo(proximo: proximo)
                            .contentShape(Rectangle())
                            .onTapGesture { alVerTodo() }
                    }
                    TarjetaFantasmaProximos()
                        .contentShape(Rectangle())
                        .onTapGesture { alVerTodo() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

struct MiniTarjetaProximo: View {
    @Environment(\.colorScheme) private var scheme
    let proximo: Proximo

    var body: some View {
        let color = KipPastel.para(proximo.comercio)
        VStack(spacing: 0) {
            Rectangle().fill(color).frame(height: 8)
            VStack(spacing: 0) {
                CirculoComercio(nombre: proximo.comercio, tamano: 46, logoUrl: proximo.logoUrl)
                Spacer().frame(height: 8)
                Text(proximo.comercio)
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.text(scheme))
                    .lineLimit(1)
                Text(proximo.montoTexto)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            Spacer(minLength: 0)
            Text(textoDias(proximo.dias).uppercased())
                .font(.manrope(11, weight: .bold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color.opacity(0.14))
        }
        .frame(width: 112, height: 168)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TarjetaFantasmaProximos: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text("Ver todo →")
            .font(.manrope(16, weight: .bold))
            .foregroundStyle(KipColor.text(scheme))
            .multilineTextAlignment(.center)
            .frame(width: 112, height: 168)
            .background(KipColor.elevated(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Cuentas

struct TarjetaCuentas: View {
    @Environment(\.colorScheme) private var scheme
    let panel: Panel

    var body: some View {
        let grupos = panel.gruposCuentas ?? []
        let totalGeneral = grupos.filter { !($0.esResumen ?? false) }.reduce(0.0) { $0 + ($1.total ?? 0) }
        KipCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Tus cuentas")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    if !grupos.isEmpty {
                        Text(dinero(totalGeneral))
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                if grupos.isEmpty {
                    Divider().background(KipColor.border(scheme))
                    if panel.cuentas.isEmpty {
                        Text("Todavía no hay cuentas conectadas.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    } else {
                        ForEach(Array(panel.cuentas.enumerated()), id: \.offset) { indice, cuenta in
                            if indice > 0 { Divider().background(KipColor.border(scheme)) }
                            FilaCuenta(cuenta: cuenta)
                        }
                    }
                } else {
                    ForEach(Array(grupos.enumerated()), id: \.offset) { indice, grupo in
                        if indice > 0 { Divider().background(KipColor.border(scheme)) }
                        FilaGrupoCuentas(grupo: grupo)
                    }
                }
                if let sincro = panel.ultimaSincronizacionTexto, !sincro.isEmpty {
                    Divider().background(KipColor.border(scheme))
                    HStack {
                        Text(sincro)
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct FilaGrupoCuentas: View {
    @Environment(\.colorScheme) private var scheme
    let grupo: GrupoCuentas
    @State private var expandido = false
    @State private var infoResumen = false

    var body: some View {
        VStack(spacing: 0) {
            Button { expandido.toggle() } label: {
                HStack(spacing: 12) {
                    CirculoIcono(simbolo: iconoGrupoCuentas(grupo.clave), color: colorGrupoCuentas(grupo.clave))
                    Text(grupo.etiqueta ?? "")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer()
                    Text(grupo.totalTexto ?? "")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    if grupo.esResumen ?? false {
                        Button { infoResumen = true } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        .buttonStyle(.plain)
                    }
                    Image(systemName: expandido ? "chevron.up" : "chevron.down")
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            if expandido {
                if grupo.esResumen ?? false {
                    Text("Es todo el dinero que tienes en tus cuentas de depósito: cheques y ahorros juntos.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                } else if (grupo.cuentas ?? []).isEmpty {
                    Text("Sin cuentas en este grupo.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(grupo.cuentas ?? []) { cuenta in
                        FilaCuenta(cuenta: cuenta)
                    }
                }
            }
        }
        .alert("Efectivo neto", isPresented: $infoResumen) {
            Button("Entendido") {}
        } message: {
            Text("Es todo el dinero que tienes en tus cuentas de depósito: cheques y ahorros juntos. No incluye tarjetas ni inversiones.")
        }
    }
}

struct FilaCuenta: View {
    @Environment(\.colorScheme) private var scheme
    let cuenta: Cuenta

    var body: some View {
        HStack(spacing: 12) {
            CirculoIcono(simbolo: iconoTipoCuenta(cuenta.tipo), color: colorTipoCuenta(cuenta.tipo))
            VStack(alignment: .leading, spacing: 2) {
                Text(cuenta.banco)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text((cuenta.mascara ?? "").isEmpty ? cuenta.nombre : "\(cuenta.nombre) · ••••\(cuenta.mascara ?? "")")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            Text(cuenta.saldoTexto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Recientes

struct TarjetaRevisaMovimientos: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        KipCard {
            HStack(spacing: 12) {
                CirculoIcono(simbolo: "magnifyingglass", color: KipPastel.azul)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Revisa tus movimientos")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Ve a dónde se va tu dinero")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(KipColor.text(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct FilaReciente: View {
    @Environment(\.colorScheme) private var scheme
    let reciente: Reciente

    var body: some View {
        HStack(spacing: 12) {
            CirculoComercio(nombre: reciente.comercio, tamano: 38, logoUrl: reciente.logoUrl)
            VStack(alignment: .leading, spacing: 2) {
                Text(reciente.comercio)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(fechaPalabras(reciente.fecha) + ((reciente.pareja?.etiqueta).map { " · \($0)" } ?? ""))
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            Text(reciente.montoTexto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Presupuesto

struct BloquePresupuesto: View {
    @Environment(\.colorScheme) private var scheme
    let presupuesto: PresupuestoMes

    var body: some View {
        let queda = presupuesto.queda ?? 0
        KipCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("Presupuesto de \(presupuesto.mesEtiqueta ?? "")")
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer().frame(height: 6)
                Text(queda >= 0 ? "Te quedan \(presupuesto.quedaTexto ?? "$0.00") para gastar" : "Te pasaste por \(dinero(-queda))")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(queda >= 0 ? KipColor.text(scheme) : Color.red)
                Text("Llevas \(presupuesto.totalGastadoTexto ?? "$0.00") de \(presupuesto.totalLimitesTexto ?? "$0.00")")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Spacer().frame(height: 10)
                BarraProgreso(fraccion: (presupuesto.porcentaje ?? 0) / 100,
                              color: (presupuesto.porcentaje ?? 0) > 100 ? .red : KipColor.gradientEnd)
                if !(presupuesto.filas ?? []).isEmpty {
                    Spacer().frame(height: 8)
                }
                ForEach(presupuesto.filas ?? []) { fila in
                    FilaPresupuesto(fila: fila)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct FilaPresupuesto: View {
    @Environment(\.colorScheme) private var scheme
    let fila: PresupuestoFila

    var body: some View {
        let color = colorDeCategoria(hex: fila.categoriaColor, clave: fila.categoria)
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.16))
                Image(systemName: iconoDeCategoria(clave: fila.categoria, icono: fila.categoriaIcono))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(fila.etiqueta ?? "")
                    .font(.manrope(17))
                    .foregroundStyle(KipColor.text(scheme))
                Text("\(fila.gastadoTexto ?? "") de \(fila.limiteTexto ?? "")")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            Spacer()
            Text("\(Int(fila.porcentaje ?? 0))%")
                .font(.manrope(15))
                .foregroundStyle((fila.porcentaje ?? 0) > 100 ? Color.red : KipColor.textSecondary(scheme))
        }
        .padding(.vertical, 6)
    }
}
