import SwiftUI

// El centro de notificaciones (NotificacionesScreen.kt de la Android):
// la lista del servidor en dos grupos, SIN LEER y LEIDAS, con el punto
// verde en las no leidas y el marcado al tocar.

@MainActor
final class NotificacionesModelo: ObservableObject {
    @Published var centro: CentroNotificaciones? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            centro = try await Api.notificaciones()
            cargando = false
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
        } catch {
            errorTexto = "No se pudieron cargar tus notificaciones."
            cargando = false
        }
    }

    func leer(_ notificacion: NotificacionCentro) async {
        if notificacion.leida { return }
        do {
            _ = try await Api.leerNotificacion(id: notificacion.id)
            await cargar()
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar() }
        } catch {}
    }

    func leerTodas() async {
        do {
            _ = try await Api.leerTodasNotificaciones()
            await cargar()
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar() }
        } catch {}
    }
}

/// El icono de cada tipo de notificacion (tabla del mapa).
func iconoNotificacion(_ tipo: String) -> String {
    switch tipo {
    case "vencimiento_deuda", "pagos_semana": return "calendar"
    case "gasto_mes": return "chart.pie"
    case "transaccion_grande": return "chart.line.uptrend.xyaxis"
    case "saldo_bajo": return "exclamationmark.triangle"
    case "salud_conexion": return "building.columns"
    case "reporte_mensual": return "doc.text"
    case "prueba_por_vencer": return "info.circle"
    case "pausa_prueba", "pausa_cancelada": return "flag"
    default: return "bell"
    }
}

struct NotificacionesView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo = NotificacionesModelo()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button { cerrar() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                Text("Notificaciones")
                    .font(.manrope(22, weight: .heavy))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                if (modelo.centro?.sinLeer ?? 0) > 0 {
                    Button("Marcar todas leídas") {
                        Task { await modelo.leerTodas() }
                    }
                    .font(.manrope(14, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            contenido
        }
        .background(KipColor.bg(scheme))
        .task { if modelo.centro == nil { await modelo.cargar() } }
    }

    @ViewBuilder
    private var contenido: some View {
        if let centro = modelo.centro {
            if centro.notificaciones.isEmpty {
                vacio(texto: nil)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        grupo(titulo: "SIN LEER", filas: centro.notificaciones.filter { !$0.leida })
                        grupo(titulo: "LEÍDAS", filas: centro.notificaciones.filter { $0.leida })
                        Color.clear.frame(height: 110)
                    }
                    .padding(.top, 4)
                }
                .refreshable { await modelo.cargar() }
            }
        } else if modelo.cargando {
            VStack { Spacer(); ProgressView().tint(KipColor.accent); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            vacio(texto: modelo.errorTexto)
        }
    }

    private func vacio(texto: String?) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Text(texto ?? "Todavía no tienes notificaciones")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .multilineTextAlignment(.center)
            Text("Cuando algo importante pase con tu dinero, lo verás aquí.")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .multilineTextAlignment(.center)
            if texto != nil {
                Button("Intentar de nuevo") { Task { await modelo.cargar() } }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private func grupo(titulo: String, filas: [NotificacionCentro]) -> some View {
        if !filas.isEmpty {
            Text(titulo)
                .font(.manrope(12, weight: .bold))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 6)
            ForEach(filas) { fila in
                Button {
                    Task { await modelo.leer(fila) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        CirculoIcono(simbolo: iconoNotificacion(fila.tipo), color: KipPastel.azul, tamano: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(fila.titulo)
                                    .font(.manrope(14, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(fila.fecha)
                                    .font(.manrope(13))
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            Text(fila.cuerpo)
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if !fila.leida {
                            Circle()
                                .fill(KipColor.accent)
                                .frame(width: 9, height: 9)
                                .padding(.top, 6)
                        }
                    }
                    .padding(14)
                    .background(KipColor.card(scheme))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(KipColor.border(scheme), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(fila.leida)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
        }
    }
}
