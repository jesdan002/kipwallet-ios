import SwiftUI

/// El estado del acceso: las mismas pantallas y textos de la app Android
/// (PantallasAcceso.kt) — Bienvenida, Entrar en dos pasos, Crear cuenta,
/// Recuperar y el paso MFA.
@MainActor
final class AccesoModel: ObservableObject {
    enum Pantalla {
        case bienvenida, login, registro, recuperar, mfa
    }

    @Published var pantalla: Pantalla = .bienvenida
    @Published var sesionIniciada = false

    // Login
    @Published var correo = ""
    @Published var contrasena = ""
    @Published var cargando = false
    @Published var error: String? = nil

    // MFA
    @Published var retoMfa: String? = nil
    @Published var metodoMfa = "correo"
    @Published var codigoMfa = ""

    // Registro
    @Published var regNombre = ""
    @Published var regCorreo = ""
    @Published var regContrasena = ""
    @Published var regAcepta = false
    @Published var regCargando = false
    @Published var regError: String? = nil

    // Recuperar
    @Published var recCargando = false
    @Published var recError: String? = nil
    @Published var recMensaje: String? = nil

    func entrar() {
        if cargando { return }
        if correo.isEmpty || contrasena.isEmpty {
            error = "Escribe tu correo y tu contraseña."
            return
        }
        cargando = true
        error = nil
        Task {
            do {
                let resultado = try await Api.login(correo: correo, contrasena: contrasena)
                cargando = false
                switch resultado {
                case .sesionIniciada:
                    contrasena = ""
                    sesionIniciada = true
                case .faltaMfa(let reto, let metodo):
                    retoMfa = reto
                    metodoMfa = metodo
                    codigoMfa = ""
                    pantalla = .mfa
                }
            } catch let falla {
                cargando = false
                self.error = (falla as? ApiError)?.errorDescription ?? "Algo salió mal."
            }
        }
    }

    func confirmarCodigo() {
        guard let reto = retoMfa else { return }
        if cargando { return }
        if codigoMfa.count < 6 {
            error = "Escribe el código completo."
            return
        }
        cargando = true
        error = nil
        Task {
            do {
                let resultado = try await Api.confirmarMfa(reto: reto, codigo: codigoMfa)
                cargando = false
                switch resultado {
                case .sesionIniciada:
                    retoMfa = nil
                    contrasena = ""
                    sesionIniciada = true
                case .faltaMfa:
                    retoMfa = nil
                    self.error = "El servidor pidió otra verificación. Intenta entrar de nuevo."
                    pantalla = .login
                }
            } catch let falla {
                cargando = false
                self.error = (falla as? ApiError)?.errorDescription ?? "Algo salió mal."
            }
        }
    }

    func crearCuenta() {
        if regCargando { return }
        if regNombre.isEmpty || regCorreo.isEmpty || regContrasena.isEmpty {
            regError = "Completa todos los datos."
            return
        }
        if !regAcepta {
            regError = "Acepta los Términos y la Política de Privacidad para continuar."
            return
        }
        regCargando = true
        regError = nil
        Task {
            do {
                let resultado = try await Api.registro(nombre: regNombre, correo: regCorreo,
                                                       contrasena: regContrasena, acepta: regAcepta)
                regCargando = false
                switch resultado {
                case .sesionIniciada:
                    regContrasena = ""
                    sesionIniciada = true
                case .faltaMfa(let reto, let metodo):
                    correo = regCorreo
                    retoMfa = reto
                    metodoMfa = metodo
                    codigoMfa = ""
                    pantalla = .mfa
                }
            } catch let falla {
                regCargando = false
                regError = (falla as? ApiError)?.errorDescription ?? "Algo salió mal."
            }
        }
    }

    func enviarRecuperacion() {
        if recCargando { return }
        if correo.isEmpty {
            recError = "Escribe tu correo."
            return
        }
        recCargando = true
        recError = nil
        Task {
            do {
                let mensaje = try await Api.olvideContrasena(correo: correo)
                recCargando = false
                recMensaje = mensaje
            } catch let falla {
                recCargando = false
                recError = (falla as? ApiError)?.errorDescription ?? "Algo salió mal."
            }
        }
    }
}

// MARK: - Piezas comunes del acceso

/// El logo oficial de la billetera KW, como lo pinta la Android:
/// la imagen cuadrada de marca con las esquinas redondeadas.
struct LogoMarca: View {
    let tamano: CGFloat
    let radio: CGFloat

    var body: some View {
        Image("LogoBilletera")
            .resizable()
            .scaledToFit()
            .frame(width: tamano, height: tamano)
            .clipShape(RoundedRectangle(cornerRadius: radio))
    }
}

struct CampoKip: View {
    @Environment(\.colorScheme) private var scheme
    let etiqueta: String
    @Binding var texto: String
    var esContrasena = false
    var tecladoEmail = false
    var tecladoNumero = false
    var alEnviar: (() -> Void)? = nil
    @State private var visible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(etiqueta)
                .font(.manrope(13, weight: .semibold))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Group {
                if esContrasena && !visible {
                    SecureField("", text: $texto)
                } else {
                    TextField("", text: $texto)
                }
            }
            .font(.manrope(16))
            .foregroundStyle(KipColor.text(scheme))
            .keyboardType(tecladoNumero ? .numberPad : (tecladoEmail ? .emailAddress : .default))
            .textInputAutocapitalization(tecladoEmail || esContrasena ? .never : .words)
            .autocorrectionDisabled(tecladoEmail || esContrasena)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(KipColor.card(scheme))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
            .overlay(alignment: .trailing) {
                if esContrasena {
                    Button { visible.toggle() } label: {
                        Image(systemName: visible ? "eye.slash" : "eye")
                            .font(.system(size: 16))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .padding(.trailing, 14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onSubmit { alEnviar?() }
        }
    }
}

struct BotonPrimario: View {
    let texto: String
    var cargando = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            HStack {
                if cargando {
                    ProgressView().tint(KipColor.onAccent)
                } else {
                    Text(texto).font(.manrope(16, weight: .bold))
                }
            }
            .foregroundStyle(KipColor.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                       startPoint: .leading, endPoint: .trailing))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(cargando)
    }
}

struct BotonContorno: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .overlay(Capsule().stroke(KipColor.text(scheme), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct EnlaceTexto: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String
    var atenuado = false
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(15, weight: atenuado ? .regular : .semibold))
                .foregroundStyle(atenuado ? KipColor.textSecondary(scheme) : KipColor.gradientEnd)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pantallas

struct RaizAccesoView: View {
    @StateObject private var modelo = AccesoModel()

    var body: some View {
        Group {
            if modelo.sesionIniciada {
                AppPrincipalView()
            } else {
                switch modelo.pantalla {
                case .bienvenida: BienvenidaView(modelo: modelo)
                case .login: LoginView(modelo: modelo)
                case .registro: RegistroView(modelo: modelo)
                case .recuperar: RecuperarView(modelo: modelo)
                case .mfa: MfaView(modelo: modelo)
                }
            }
        }
    }
}

/// La bienvenida: el logo grande y las dos entradas, como la primera
/// pantalla de Rocket que replica la Android.
struct BienvenidaView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AccesoModel

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()
            VStack {
                Spacer().frame(height: 72)
                LogoMarca(tamano: 120, radio: 28)
                Spacer().frame(height: 20)
                Text("Kipwallet")
                    .font(.manrope(36, weight: .heavy))
                    .foregroundStyle(KipColor.accent)
                Spacer().frame(height: 8)
                Text("Sal de tus tarjetas. Ordena tu cheque. Entiende tu dinero.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 48)
                BotonPrimario(texto: "Crear cuenta") { modelo.pantalla = .registro }
                Spacer().frame(height: 12)
                BotonContorno(texto: "Ya tengo cuenta · Entrar") { modelo.pantalla = .login }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }
}

/// El acceso en dos pasos: primero el correo y al continuar,
/// "Hola de nuevo" con la contrasena.
struct LoginView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AccesoModel
    @State private var paso = 1
    @State private var errorCorreo: String? = nil

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()
            ScrollView {
                VStack {
                    Spacer().frame(height: 24)
                    LogoMarca(tamano: 92, radio: 21)
                    Spacer().frame(height: 16)
                    if paso == 1 {
                        Text("Entra a tu cuenta")
                            .font(.manrope(24, weight: .heavy))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer().frame(height: 8)
                        Text("Escribe tu correo para continuar.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 32)
                        CampoKip(etiqueta: "Correo", texto: $modelo.correo, tecladoEmail: true) { continuar() }
                        if let errorCorreo = errorCorreo {
                            Spacer().frame(height: 16)
                            Text(errorCorreo)
                                .font(.manrope(15))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        Spacer().frame(height: 24)
                        BotonPrimario(texto: "Continuar") { continuar() }
                        Spacer().frame(height: 8)
                        EnlaceTexto(texto: "¿Olvidaste tu contraseña?") {
                            modelo.recMensaje = nil
                            modelo.recError = nil
                            modelo.pantalla = .recuperar
                        }
                        EnlaceTexto(texto: "¿No tienes cuenta? Crear cuenta", atenuado: true) { modelo.pantalla = .registro }
                        EnlaceTexto(texto: "Volver", atenuado: true) { modelo.pantalla = .bienvenida }
                    } else {
                        Text("Hola de nuevo")
                            .font(.manrope(24, weight: .heavy))
                            .foregroundStyle(KipColor.text(scheme))
                        Spacer().frame(height: 8)
                        Text(modelo.correo)
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 32)
                        CampoKip(etiqueta: "Contraseña", texto: $modelo.contrasena, esContrasena: true) { modelo.entrar() }
                        if let error = modelo.error {
                            Spacer().frame(height: 16)
                            Text(error)
                                .font(.manrope(15))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        Spacer().frame(height: 24)
                        BotonPrimario(texto: "Entrar", cargando: modelo.cargando) { modelo.entrar() }
                        Spacer().frame(height: 8)
                        EnlaceTexto(texto: "¿Olvidaste tu contraseña?") {
                            modelo.recMensaje = nil
                            modelo.recError = nil
                            modelo.pantalla = .recuperar
                        }
                        EnlaceTexto(texto: "Usar otro correo", atenuado: true) { paso = 1 }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
        .onAppear { modelo.correo = modelo.correo.isEmpty ? (Sesion.correo ?? "") : modelo.correo }
    }

    private func continuar() {
        if modelo.correo.trimmingCharacters(in: .whitespaces).isEmpty {
            errorCorreo = "Escribe tu correo."
        } else {
            errorCorreo = nil
            paso = 2
        }
    }
}

/// Crear cuenta, como la primera ronda de la web y la Android.
struct RegistroView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AccesoModel

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()
            ScrollView {
                VStack {
                    Spacer().frame(height: 24)
                    Text("Crea tu cuenta")
                        .font(.manrope(28, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer().frame(height: 8)
                    Text("Sal de tus tarjetas. Ordena tu cheque. Entiende tu dinero.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 32)
                    CampoKip(etiqueta: "Nombre", texto: $modelo.regNombre)
                    Spacer().frame(height: 16)
                    CampoKip(etiqueta: "Correo", texto: $modelo.regCorreo, tecladoEmail: true)
                    Spacer().frame(height: 16)
                    CampoKip(etiqueta: "Contraseña", texto: $modelo.regContrasena, esContrasena: true) { modelo.crearCuenta() }
                    Text("Mínimo 8 caracteres")
                        .font(.manrope(12))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    Spacer().frame(height: 16)
                    Button {
                        modelo.regAcepta.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: modelo.regAcepta ? "checkmark.square.fill" : "square")
                                .foregroundStyle(modelo.regAcepta ? KipColor.gradientEnd : KipColor.textSecondary(scheme))
                                .font(.system(size: 22))
                            Text("Acepto los Términos y la Política de Privacidad")
                                .font(.manrope(15))
                                .foregroundStyle(KipColor.text(scheme))
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    HStack {
                        Link("Ver Términos", destination: URL(string: "https://app.kipwallet.com/terminos")!)
                            .font(.manrope(15, weight: .semibold))
                            .foregroundStyle(KipColor.gradientEnd)
                        Spacer().frame(width: 16)
                        Link("Ver Privacidad", destination: URL(string: "https://app.kipwallet.com/privacidad")!)
                            .font(.manrope(15, weight: .semibold))
                            .foregroundStyle(KipColor.gradientEnd)
                        Spacer()
                    }
                    if let error = modelo.regError {
                        Spacer().frame(height: 8)
                        Text(error)
                            .font(.manrope(15))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    Spacer().frame(height: 16)
                    BotonPrimario(texto: "Crear cuenta", cargando: modelo.regCargando) { modelo.crearCuenta() }
                    Spacer().frame(height: 8)
                    EnlaceTexto(texto: "Ya tengo cuenta · Entrar", atenuado: true) { modelo.pantalla = .login }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
    }
}

/// Recuperar contrasena: el servidor manda el enlace y la contrasena
/// nueva se escribe en la web, igual que en la Android.
struct RecuperarView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AccesoModel

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()
            ScrollView {
                VStack {
                    Spacer().frame(height: 24)
                    LogoMarca(tamano: 92, radio: 21)
                    Spacer().frame(height: 16)
                    Text("Recupera tu contraseña")
                        .font(.manrope(24, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 8)
                    Text("Escribe tu correo y te mandamos un enlace. Al tocarlo podrás escribir tu contraseña nueva.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 32)
                    if let mensaje = modelo.recMensaje {
                        Text(mensaje)
                            .font(.manrope(17))
                            .foregroundStyle(KipColor.text(scheme))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 16)
                        Text("Si no lo ves, revisa la carpeta de spam.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                            .multilineTextAlignment(.center)
                        Spacer().frame(height: 24)
                        BotonPrimario(texto: "Volver a entrar") { modelo.pantalla = .login }
                    } else {
                        CampoKip(etiqueta: "Correo", texto: $modelo.correo, tecladoEmail: true) { modelo.enviarRecuperacion() }
                        if let error = modelo.recError {
                            Spacer().frame(height: 16)
                            Text(error)
                                .font(.manrope(15))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        Spacer().frame(height: 24)
                        BotonPrimario(texto: "Mandarme el enlace", cargando: modelo.recCargando) { modelo.enviarRecuperacion() }
                        Spacer().frame(height: 8)
                        EnlaceTexto(texto: "Volver", atenuado: true) { modelo.pantalla = .login }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
    }
}

/// El paso MFA: "Un paso mas", con el codigo del correo o de la app.
struct MfaView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AccesoModel

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()
            ScrollView {
                VStack {
                    Spacer().frame(height: 24)
                    Text("Un paso más")
                        .font(.manrope(24, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Spacer().frame(height: 8)
                    Text(modelo.metodoMfa == "correo"
                         ? "Te enviamos un código a tu correo. Escríbelo aquí para terminar de entrar."
                         : "Escribe el código de tu aplicación de autenticación.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 32)
                    CampoKip(etiqueta: "Código", texto: Binding(
                        get: { modelo.codigoMfa },
                        set: { modelo.codigoMfa = String($0.filter { $0.isNumber }.prefix(8)) }
                    ), tecladoNumero: true) { modelo.confirmarCodigo() }
                    if let error = modelo.error {
                        Spacer().frame(height: 16)
                        Text(error)
                            .font(.manrope(15))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    Spacer().frame(height: 24)
                    BotonPrimario(texto: "Confirmar", cargando: modelo.cargando) { modelo.confirmarCodigo() }
                    Spacer().frame(height: 8)
                    EnlaceTexto(texto: "Volver", atenuado: true) {
                        modelo.retoMfa = nil
                        modelo.pantalla = .login
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
        }
    }
}
