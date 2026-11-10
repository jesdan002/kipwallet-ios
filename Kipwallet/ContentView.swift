import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var selected = 2 // el heroe (Panel) al centro, como en la familia

    var body: some View {
        ZStack {
            KipColor.bg(scheme).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // El logo oficial de la marca (la billetera KW), el mismo
                // de la app Android — nada de simbolos genericos.
                Image("LogoBilletera")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                VStack(spacing: 8) {
                    Text("Kipwallet")
                        .font(.manrope(30, weight: .heavy))
                        .foregroundStyle(KipColor.text(scheme))
                    Text("Tu dinero, en orden: sal de deudas y planifica sin humo.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .multilineTextAlignment(.center)
                }

                EstadoProyecto()
                    .padding(.horizontal, 32)

                Spacer()
            }

            // Capsula flotante con heroe central: la navegacion de la familia Kip.
            VStack {
                Spacer()
                BarraCapsula(selected: $selected)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
        }
    }
}

struct EstadoProyecto: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RenglonEstado(texto: "Proyecto iOS creado en la iMac de la familia")
            RenglonEstado(texto: "Servidor: el unico que manda — app.kipwallet.com")
            RenglonEstado(texto: "Siguiente paso: login con MFA y el Panel con datos reales")
        }
        .padding(16)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct RenglonEstado: View {
    @Environment(\.colorScheme) private var scheme
    let texto: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(KipColor.accent)
            Text(texto)
                .font(.manrope(14))
                .foregroundStyle(KipColor.text(scheme))
        }
    }
}

/// La barra de la familia: capsula flotante con margen y sombra,
/// y el boton central (el Panel) como circulo verde grande.
struct BarraCapsula: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var selected: Int

    private let items: [(symbol: String, title: String, hero: Bool)] = [
        ("arrow.down.circle.fill", "Deudas", false),
        ("chart.pie.fill", "Gastos", false),
        ("house.fill", "Panel", true),
        ("arrow.left.arrow.right", "Movimientos", false),
        ("ellipsis.circle.fill", "Más", false)
    ]

    var body: some View {
        // Misma estructura que la capsula de Kiptrade: la fila visible
        // (solo laterales + hueco central) va recortada en capsula con
        // su sombra en un fondo gemelo sin recorte, y el heroe vive
        // FUERA de esa fila, en un ZStack alineado al fondo, para que
        // nada lo recorte y la barra quede pegada como en Kiptrade
        // (sin la holgura extra que KW traia).
        ZStack(alignment: .bottom) {
            HStack(alignment: .center, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    if item.hero {
                        Color.clear.frame(width: 68)
                    } else {
                        Button {
                            selected = index
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 20))
                                Text(item.title)
                                    .font(.manrope(10, weight: .semibold))
                            }
                            .foregroundStyle(selected == index ? KipColor.accent : KipColor.textSecondary(scheme))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 62)
            .background(KipColor.card(scheme))
            .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: 1))
            .clipShape(Capsule())
            .background(
                Capsule()
                    .fill(KipColor.card(scheme))
                    .shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.15), radius: 14, y: 6)
            )
            Button {
                selected = 2
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [KipColor.gradientStart, KipColor.gradientEnd],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 5)
                    Image(systemName: "house.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(KipColor.onAccent)
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, 17)
            .zIndex(1)
        }
        .frame(height: 62)
    }
}

