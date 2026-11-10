import SwiftUI

@main
struct KipwalletApp: App {
    var body: some Scene {
        WindowGroup {
            // Si ya hay token guardado, la app abre directo en el Panel;
            // si no, en el acceso (bienvenida / entrar / crear cuenta).
            if Sesion.token != nil {
                AppPrincipalView()
            } else {
                RaizAccesoView()
            }
        }
    }
}
