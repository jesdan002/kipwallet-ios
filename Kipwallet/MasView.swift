import SwiftUI

// La pestana Mas (MasScreen.kt de la Android): la cuadricula de
// secciones que no viven en la capsula, la tarjeta Aprende con sus 6
// lecciones locales, Ayudame a mejorar, la entrada a Ajustes y el
// boton de cerrar sesion.

@MainActor
final class MasModelo: ObservableObject {
    @Published var membresia: MembresiaDto? = nil
    @Published var cerrando = false

    func cargar() async {
        do {
            membresia = try await Api.mas().membresia
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar() }
        } catch {}
    }

    func cerrarSesion() async {
        if cerrando { return }
        cerrando = true
        await Api.logout()
        Sesion.cerrar()
    }
}

struct MasView: View {
    @Environment(\.colorScheme) private var scheme
    var alIrRecurrentes: () -> Void = {}
    var alIrAjustes: () -> Void = {}
    var alIrPatrimonio: () -> Void = {}
    var alIrMetas: () -> Void = {}
    var alIrPresupuesto: () -> Void = {}
    var alIrPronostico: () -> Void = {}
    @StateObject private var modelo = MasModelo()
    @State private var sub: String? = nil
    @State private var avisoConstruccion: String? = nil

    var body: some View {
        Group {
            if sub == "aprende" {
                AprendeView(alVolver: { sub = nil })
            } else if sub == "mejorar" {
                MejorarView(alVolver: { sub = nil })
            } else {
                principal
            }
        }
        .task { await modelo.cargar() }
        .alert("En construcción", isPresented: Binding(get: { avisoConstruccion != nil }, set: { if !$0 { avisoConstruccion = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("La pantalla \(avisoConstruccion ?? "") se construye en la siguiente ronda, igual que en tu Android.")
        }
    }

    private var principal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Más")
                    .font(.manrope(28, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                Text("Todo lo demás de tu Kipwallet, en un solo lugar.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                cuadricula
                tarjetaAprende
                tarjetaMejorar
                tarjetaAjustes
                Button {
                    Task { await modelo.cerrarSesion() }
                } label: {
                    Text(modelo.cerrando ? "Cerrando…" : "Cerrar sesión")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(modelo.cerrando)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                Color.clear.frame(height: 110)
            }
        }
        .background(KipColor.bg(scheme))
    }

    private var cuadricula: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            mosaico(titulo: "Recurrentes", texto: "Tus cobros que se repiten y el calendario",
                    simbolo: "repeat", color: KipPastel.indigo) { alIrRecurrentes() }
            mosaico(titulo: "Patrimonio", texto: "Lo que tienes menos lo que debes",
                    simbolo: "wallet.pass.fill", color: KipPastel.cafe) { alIrPatrimonio() }
            mosaico(titulo: "Metas", texto: "Ahorra para lo que quieres lograr",
                    simbolo: "target", color: KipPastel.verde) { alIrMetas() }
            mosaico(titulo: "Presupuesto", texto: "Lo que entra, lo que sale y tu plan del mes",
                    simbolo: "chart.pie.fill", color: KipPastel.naranja) { alIrPresupuesto() }
            mosaico(titulo: "Pronóstico", texto: "Cómo se ve tu dinero en los próximos meses",
                    simbolo: "chart.line.uptrend.xyaxis", color: KipPastel.morado) { alIrPronostico() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func mosaico(titulo: String, texto: String, simbolo: String, color: Color, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            VStack(alignment: .leading, spacing: 8) {
                CirculoIcono(simbolo: simbolo, color: color)
                Text(titulo)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text(texto)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var tarjetaAprende: some View {
        Button { sub = "aprende" } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.22))
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aprende")
                        .font(.manrope(20, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Lecciones cortas para salir de deudas y entender tu dinero, sin tecnicismos.")
                        .font(.manrope(14))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white)
            }
            .padding(16)
            .background(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var tarjetaMejorar: some View {
        Button { sub = "mejorar" } label: {
            HStack(spacing: 14) {
                CirculoIcono(simbolo: "envelope.fill", color: KipPastel.verde)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ayúdame a mejorar")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Cuéntame qué no se entiende, qué falló o qué idea tienes. Me llega directo a mí.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(16)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var tarjetaAjustes: some View {
        Button { alIrAjustes() } label: {
            HStack(spacing: 14) {
                CirculoIcono(simbolo: "gearshape.fill", color: KipPastel.indigo)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ajustes")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Tu perfil, tu banco, tu membresía, avisos, temas y seguridad")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(16)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - Aprende (contenido local, igual que la Android)

struct LeccionAprende {
    let titulo: String
    let minutos: Int
    let parrafos: [String]
}

let LECCIONES_APRENDE: [LeccionAprende] = [
    LeccionAprende(titulo: "Sal del mínimo: así se sale de una tarjeta", minutos: 3, parrafos: [
        "El pago mínimo de una tarjeta está hecho para que la deuda dure años. Cubre los intereses del mes y un pedacito muy chico del saldo, así que casi todo lo que debes sigue ahí, generando intereses otra vez.",
        "La salida no es pagar todo de golpe: es pagar más del mínimo, siempre lo mismo cada mes. Aunque sean 25 o 50 dólares extra, ese dinero va directo al saldo y cada mes debes menos, pagas menos intereses y la fecha en que sales se acerca sola.",
        "En Kipwallet no tienes que registrar nada a mano: pagas como siempre y, cuando el pago se refleja en tu banco, tu fecha de libertad se mueve sola. Mírala en la pestaña Deudas.",
    ]),
    LeccionAprende(titulo: "Interés primero o efecto dominó: elige tu camino", minutos: 3, parrafos: [
        "Cuando tienes varias tarjetas, el orden en que las pagas cambia cuánto pagas en total y qué tan rápido sales. Hay dos caminos conocidos, y los dos funcionan si los sostienes.",
        "Interés primero: tu dinero extra va a la tarjeta con el interés (APR) más alto. Es el camino que menos dinero te cuesta en total, porque apagas primero la deuda que más caro te cobra cada mes.",
        "Efecto dominó: tu dinero extra va a la deuda más chica, sin importar el interés. Saldar una tarjeta completa anima mucho, y ese ánimo ayuda a no soltar el plan. En Deudas puedes probar los dos con el simulador y ver, con tus números, cuál te conviene.",
    ]),
    LeccionAprende(titulo: "Tu fondo de emergencia, sin dramas", minutos: 2, parrafos: [
        "Un fondo de emergencia es dinero guardado solo para imprevistos: la llanta que se poncha, la visita al dentista, la semana sin trabajo. Sin ese colchón, cada imprevisto termina en la tarjeta, y la deuda vuelve a crecer.",
        "No necesitas juntar tres meses de gastos de una vez. Empieza con una meta chica, 500 o 1,000 dólares, en una cuenta de ahorros separada. Al llegar, la siguiente meta puede ser un mes de tus gastos básicos.",
        "Créala en Metas y aporta de poco en poco, como puedas. Lo importante no es la cantidad de hoy: es el hábito de que cada pago te deje un poco más cubierto.",
    ]),
    LeccionAprende(titulo: "Presupuesto por ciclo de pago, no por mes", minutos: 3, parrafos: [
        "Casi todos los presupuestos se arman por mes, pero tu dinero no llega por mes: llega cada vez que te pagan. Por eso a mitad de quincena el dinero «desaparece»: los cobros fuertes cayeron antes del siguiente pago.",
        "La forma que sí funciona es ordenar tus gastos alrededor de tus días de pago: qué cobros salen de este cheque y cuáles del siguiente. Así nunca te quedas sin nada antes de cobrar, y sabes cuánto puedes gastar sin tocar lo que ya tiene dueño.",
        "Configura tu ciclo en Ajustes y Kipwallet acomoda tu presupuesto y tu calendario de cobros alrededor de tus pagos reales, no de un mes imaginario.",
    ]),
    LeccionAprende(titulo: "Las suscripciones que olvidaste", minutos: 2, parrafos: [
        "Casi todos pagamos algo que ya no usamos: la prueba gratis que se cobró sola, la app que abriste dos veces, el servicio que subió de precio sin avisar. De a poquito, esos cobros se comen lo que podría ir a tu deuda o a tu ahorro.",
        "Revisa tus cargos que se repiten una vez al mes: si no reconoces uno o no lo usaste en 30 días, cancélalo ese mismo día. Y ojo con los «paga en 4»: no son una suscripción, pero comprometen tus próximos cheques igual.",
        "En Recurrentes ves todos tus cobros repetidos juntos, con cuánto suman al año. Ese número, visto de frente, suele convencer más que cualquier consejo.",
    ]),
    LeccionAprende(titulo: "Qué es el APR, en palabras simples", minutos: 2, parrafos: [
        "El APR es el precio de deber dinero, expresado como un porcentaje al año. Si tu tarjeta dice 28% APR, quiere decir que por cada 100 dólares que debes durante un año, el banco te cobra unos 28 dólares solo por prestártelos.",
        "Suena lejano, pero se cobra mes a mes: 28% al año es como 2.3% cada mes sobre lo que debes. Con un saldo de 900 dólares, son unos 21 dólares de intereses cada mes que no compran nada: solo rentan la deuda.",
        "Por eso importa tanto bajar primero la deuda con el APR más alto, y por eso en Kipwallet cada tarjeta enseña su APR junto a su saldo: es el dato que decide por dónde empezar.",
    ]),
]

struct AprendeView: View {
    @Environment(\.colorScheme) private var scheme
    var alVolver: () -> Void = {}
    @State private var elegida: LeccionAprende? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { if elegida != nil { elegida = nil } else { alVolver() } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text("Aprende")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            if let leccion = elegida {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(leccion.titulo)
                            .font(.manrope(22, weight: .heavy))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("Lectura de \(leccion.minutos) minutos")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        ForEach(leccion.parrafos, id: \.self) { parrafo in
                            Text(parrafo)
                                .font(.manrope(17))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lecciones cortas, en palabras simples. Primero salir de deudas, luego planificar mejor.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        ForEach(LECCIONES_APRENDE, id: \.titulo) { leccion in
                            Button { elegida = leccion } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(leccion.titulo)
                                            .font(.manrope(16, weight: .bold))
                                            .foregroundStyle(KipColor.text(scheme))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(leccion.minutos) minutos")
                                            .font(.manrope(14))
                                            .foregroundStyle(KipColor.textSecondary(scheme))
                                    }
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                .padding(16)
                                .background(KipColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .background(KipColor.bg(scheme))
    }
}

// MARK: - Ayudame a mejorar

struct MejorarView: View {
    @Environment(\.colorScheme) private var scheme
    var alVolver: () -> Void = {}
    @State private var tipo = "no_se_entiende"
    @State private var intentabas = ""
    @State private var mensaje = ""
    @State private var correo = ""
    @State private var errorTexto: String? = nil
    @State private var enviando = false
    @State private var enviado = false

    private let tipos: [(String, String)] = [
        ("no_se_entiende", "Algo no se entiende"), ("fallo", "Algo falló"),
        ("idea", "Tengo una idea"), ("otro", "Otro"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { alVolver() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text("Ayúdame a mejorar")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            if enviado {
                VStack(spacing: 14) {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(KipColor.gradientEnd)
                    Text("¡Gracias! Tu mensaje ya llegó.")
                        .font(.manrope(20, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .multilineTextAlignment(.center)
                    Text("Lo leo yo personalmente. Si dejaste tu correo y hace falta, te respondo por ahí.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Volver") { alVolver() }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.horizontal, 28)
                        .frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Cuéntame qué no se entiende, qué falló o qué te gustaría ver en Kipwallet. Este mensaje me llega directo a mí, el creador, y lo leo personalmente.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.text(scheme))
                        Text("Solo me llega lo que escribas aquí y desde qué pantalla lo enviaste. Nunca datos de tu banco, saldos ni movimientos.")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Text("¿QUÉ TIPO DE MENSAJE ES?")
                            .font(.manrope(12, weight: .bold))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(tipos, id: \.0) { opcion in
                                let elegido = tipo == opcion.0
                                Button(opcion.1) { tipo = opcion.0 }
                                    .font(.manrope(14, weight: .bold))
                                    .foregroundStyle(elegido ? KipColor.onAccent : KipColor.text(scheme))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(elegido ? KipColor.accent : KipColor.card(scheme))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: elegido ? 0 : 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        CampoKip(etiqueta: "¿Qué intentabas hacer?", texto: $intentabas)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tu mensaje")
                                .font(.manrope(13, weight: .semibold))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                            TextEditor(text: $mensaje)
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                                .frame(minHeight: 110)
                                .padding(8)
                                .background(KipColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        CampoKip(etiqueta: "Tu correo, si quieres que te responda (opcional)", texto: $correo, tecladoEmail: true)
                        if let error = errorTexto {
                            Text(error)
                                .font(.manrope(14))
                                .foregroundStyle(Color.red)
                        }
                        BotonPrimario(texto: enviando ? "Enviando…" : "Enviar mensaje", cargando: enviando) { enviar() }
                        Color.clear.frame(height: 110)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .background(KipColor.bg(scheme))
    }

    private func enviar() {
        let intentabasLimpio = intentabas.trimmingCharacters(in: .whitespaces)
        let mensajeLimpio = mensaje.trimmingCharacters(in: .whitespaces)
        let correoLimpio = correo.trimmingCharacters(in: .whitespaces)
        if intentabasLimpio.isEmpty || mensajeLimpio.isEmpty {
            errorTexto = "Cuéntame qué intentabas hacer y tu mensaje, por favor."
            return
        }
        if !correoLimpio.isEmpty && !correoLimpio.contains("@") {
            errorTexto = "Ese correo no se ve completo. Revísalo o déjalo vacío."
            return
        }
        errorTexto = nil
        enviando = true
        Task {
            do {
                _ = try await Api.mejorar(tipo: tipo, intentabas: intentabasLimpio,
                                          mensaje: mensajeLimpio,
                                          correo: correoLimpio.isEmpty ? nil : correoLimpio)
                enviando = false
                enviado = true
            } catch let e as ApiError {
                enviando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorTexto = e.errorDescription
            } catch {
                enviando = false
                errorTexto = "No se pudo enviar tu mensaje. Intenta de nuevo."
            }
        }
    }
}
