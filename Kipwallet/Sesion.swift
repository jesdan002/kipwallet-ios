import Foundation
import Security

/// La sesion de Kipwallet iOS: el token de Sanctum vive en el Keychain
/// del aparato (nunca en archivos planos), igual que en la app Android
/// el token vive en su almacen cifrado. El servidor es la unica verdad:
/// la app solo guarda el token y su correo para re-entrar.
///
/// Respaldo DEBUG: los builds de simulador corren sin firma
/// (CODE_SIGNING_ALLOWED=NO) y el Keychain sin identidad falla en
/// silencio con errSecMissingEntitlement (-34018): el token no se
/// guarda, el Panel sale sin Authorization y el servidor responde 401.
/// En DEBUG, si el Keychain no confirma la escritura, el token cae a
/// UserDefaults para que el flujo se pueda probar; los builds de
/// produccion (Release) usan SOLO el Keychain, sin respaldo.
enum Sesion {
    private static let servicio = "com.kipwallet.app"
    private static let cuentaToken = "token-api"
    private static let cuentaCorreo = "correo"
    private static let claveRespaldo = "token-api-respaldo-debug"

    static var token: String? {
        get {
            if let delLlavero = leer(cuentaToken) { return delLlavero }
            #if DEBUG
            return UserDefaults.standard.string(forKey: claveRespaldo)
            #else
            return nil
            #endif
        }
        set {
            if let nuevo = newValue {
                if guardar(nuevo, cuenta: cuentaToken) {
                    #if DEBUG
                    UserDefaults.standard.removeObject(forKey: claveRespaldo)
                    #endif
                } else {
                    #if DEBUG
                    UserDefaults.standard.set(nuevo, forKey: claveRespaldo)
                    #endif
                }
            } else {
                borrar(cuentaToken)
                #if DEBUG
                UserDefaults.standard.removeObject(forKey: claveRespaldo)
                #endif
            }
        }
    }

    static var correo: String? {
        get { UserDefaults.standard.string(forKey: cuentaCorreo) }
        set { UserDefaults.standard.set(newValue, forKey: cuentaCorreo) }
    }

    static func cerrar() {
        token = nil
    }

    // MARK: - Keychain

    /// Devuelve true solo si el Keychain confirmo la escritura.
    @discardableResult
    private static func guardar(_ valor: String, cuenta: String) -> Bool {
        let datos = Data(valor.utf8)
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
        var alta = consulta
        alta[kSecValueData as String] = datos
        alta[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let estado = SecItemAdd(alta as CFDictionary, nil)
        if estado == errSecSuccess { return true }
        #if DEBUG
        NSLog("KW-DEBUG Sesion: Keychain SecItemAdd fallo con OSStatus %d; usando respaldo DEBUG", estado)
        #endif
        return false
    }

    private static func leer(_ cuenta: String) -> String? {
        var consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        consulta[kSecReturnData as String] = true
        consulta[kSecMatchLimit as String] = kSecMatchLimitOne
        var resultado: AnyObject?
        guard SecItemCopyMatching(consulta as CFDictionary, &resultado) == errSecSuccess,
              let datos = resultado as? Data else { return nil }
        return String(data: datos, encoding: .utf8)
    }

    private static func borrar(_ cuenta: String) {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuenta,
        ]
        SecItemDelete(consulta as CFDictionary)
    }
}
