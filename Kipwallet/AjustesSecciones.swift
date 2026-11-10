import SwiftUI
import UIKit

// Las subsecciones de Ajustes (AjustesSecciones.kt de la Android):
// Ciclo de pago, Categorias (colores y personalizadas), Reglas de
// movimientos, Verificacion en dos pasos, Conecta tu asistente y
// Cambiar mi contrasena. Cada una reemplaza la lista con su cabecera.

struct CabeceraSeccionAjustes: View {
    @Environment(\.colorScheme) private var scheme
    let titulo: String
    let alVolver: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button { alVolver() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KipColor.text(scheme))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Text(titulo)
                .font(.manrope(20, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

struct FondoSeccionAjustes<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(KipColor.bg(scheme))
    }
}

// MARK: - Ciclo de pago

struct CicloPagoAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var frecuencia: String? = nil
    @State private var diaA = ""
    @State private var diaB = ""
    @State private var fechaPago = Date()
    @State private var sembrado = false

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Ciclo de pago", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Cuéntanos cómo te pagan: con eso armamos tu presupuesto por ciclo y sabemos qué cobros caen antes de tu próximo pago.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                    if let sugerencia = modelo.ajustes?.ciclo?.sugerenciaFrecuencia {
                        Text("Por tus ingresos, parece que te pagan: \(etiquetaFrecuencia(sugerencia)).")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    }
                    Text("¿Cada cuánto te pagan?")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(clavesFrecuencia, id: \.self) { clave in
                            let elegida = frecuencia == clave
                            Button(etiquetaFrecuencia(clave)) { frecuencia = clave }
                                .font(.manrope(14, weight: .bold))
                                .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(elegida ? KipColor.accent : KipColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    if frecuencia == "dos_veces_mes" {
                        HStack(spacing: 12) {
                            CampoKip(etiqueta: "Primer día", texto: $diaA, tecladoNumero: true)
                            CampoKip(etiqueta: "Segundo día", texto: $diaB, tecladoNumero: true)
                        }
                        Text("Los dos días del mes en que te pagan (por ejemplo, 1 y 15).")
                            .font(.manrope(13))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    } else if frecuencia != nil {
                        Text("¿Cuándo es tu próximo pago?")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                        DatePicker("", selection: $fechaPago, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(KipColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    BotonPrimario(texto: "Guardar mi ciclo") { guardar() }
                        .disabled(frecuencia == nil || modelo.procesando)
                        .opacity(frecuencia == nil ? 0.5 : 1)
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .onAppear { sembrar() }
    }

    private var clavesFrecuencia: [String] {
        let delServidor = modelo.ajustes?.ciclo?.frecuencias ?? []
        return delServidor.isEmpty ? ["semanal", "quincenal", "dos_veces_mes", "mensual"] : delServidor
    }

    private func sembrar() {
        if sembrado { return }
        sembrado = true
        guard let ciclo = modelo.ajustes?.ciclo else { return }
        frecuencia = ciclo.frecuencia
        diaA = ciclo.diaA.map { String($0) } ?? ""
        diaB = ciclo.diaB.map { String($0) } ?? ""
        if let proximo = ciclo.proximoPago, let fecha = parseFecha(proximo) {
            fechaPago = fecha
        }
    }

    private func guardar() {
        guard let frec = frecuencia else { return }
        var cuerpo: [String: Any] = ["pay_frequency": frec]
        if frec == "dos_veces_mes" {
            cuerpo["next_payday"] = NSNull()
            cuerpo["payday_day_a"] = Int(diaA) ?? NSNull()
            cuerpo["payday_day_b"] = Int(diaB) ?? NSNull()
        } else {
            cuerpo["next_payday"] = isoDeFecha(fechaPago)
            cuerpo["payday_day_a"] = NSNull()
            cuerpo["payday_day_b"] = NSNull()
        }
        modelo.ejecutar(alExito: alVolver) { try await Api.guardarCiclo(cuerpo: cuerpo).mensaje }
    }
}

// MARK: - Categorias

struct CategoriasAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var colorElegido: ColorCategoria? = nil
    @State private var editando: CategoriaPersonalizada? = nil
    @State private var creando = false

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Categorías", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Toca una categoría para cambiar su color.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.vertical, 8)
                    ForEach(modelo.ajustes?.colores ?? []) { color in
                        Button { colorElegido = color } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(hexCadena: color.color)).frame(width: 30, height: 30)
                                Text(color.nombre)
                                    .font(.manrope(17))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                if color.personalizado {
                                    Text("Tu color")
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider().background(KipColor.border(scheme))
                    }
                    RotuloAjustes(texto: "TUS CATEGORÍAS")
                        .padding(.top, 20)
                        .padding(.bottom, 6)
                    Text("Crea las tuyas con el nombre que tú usas — como «Mascotas» o «Consignación» — y aparecerán en todo: al clasificar un movimiento, en presupuestos, en Gastos y en tus reglas. Tu banco no clasifica solo en ellas: llegan cuando mueves un cargo, y la app aprende de tus correcciones igual que con las demás.")
                        .font(.manrope(14))
                        .foregroundStyle(KipColor.textSecondary(scheme))
                        .padding(.bottom, 8)
                    ForEach(modelo.ajustes?.personalizadas ?? []) { categoria in
                        Button { editando = categoria } label: {
                            HStack(spacing: 12) {
                                CirculoIcono(simbolo: iconoPorNombre(categoria.icono),
                                             color: Color(hexCadena: categoria.color), tamano: 34)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(categoria.nombre)
                                        .font(.manrope(17))
                                        .foregroundStyle(KipColor.text(scheme))
                                    Text(categoria.tipo == "ingreso" ? "Ingreso" : "Gasto")
                                        .font(.manrope(13))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(KipColor.textSecondary(scheme))
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider().background(KipColor.border(scheme))
                    }
                    botonContornoAjustes("Nueva categoría") { creando = true }
                        .padding(.top, 14)
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(item: $colorElegido) { color in
            SelectorColorCategoriaView(modelo: modelo, categoria: color)
        }
        .sheet(item: $editando) { categoria in
            EditorCategoriaPersonalizadaView(modelo: modelo, existente: categoria)
        }
        .sheet(isPresented: $creando) {
            EditorCategoriaPersonalizadaView(modelo: modelo, existente: nil)
        }
    }
}

struct SelectorColorCategoriaView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: AjustesModelo
    let categoria: ColorCategoria

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(categoria.nombre)
                .font(.manrope(20, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text("Elige el color de esta categoría en tus gráficas.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(PALETA_COLORES_CATEGORIA, id: \.self) { hex in
                    Button {
                        modelo.ejecutar(alExito: { cerrar() }) {
                            try await Api.guardarColorCategoria(clave: categoria.clave, color: hex, restablecer: false).mensaje
                        }
                    } label: {
                        Circle()
                            .fill(Color(hexCadena: hex))
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(KipColor.text(scheme),
                                                     lineWidth: hex.lowercased() == categoria.color.lowercased() ? 3 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            if categoria.personalizado {
                Button("Volver al color de la app") {
                    modelo.ejecutar(alExito: { cerrar() }) {
                        try await Api.guardarColorCategoria(clave: categoria.clave, color: nil, restablecer: true).mensaje
                    }
                }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.gradientEnd)
            }
            Button("Cerrar") { cerrar() }
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
        }
        .padding(20)
        .background(KipColor.bg(scheme))
    }
}

struct EditorCategoriaPersonalizadaView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: AjustesModelo
    let existente: CategoriaPersonalizada?
    @State private var nombre = ""
    @State private var colorHex = "#D97706"
    @State private var icono = "etiqueta"
    @State private var tipo = "gasto"
    @State private var sembrado = false
    @State private var confirmarBorrar = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(existente == nil ? "Nueva categoría" : "Editar categoría")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                CampoKip(etiqueta: "Nombre", texto: $nombre)
                Text("Color")
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(PALETA_COLORES_CATEGORIA, id: \.self) { hex in
                        Button { colorHex = hex } label: {
                            Circle()
                                .fill(Color(hexCadena: hex))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(KipColor.text(scheme),
                                                         lineWidth: hex.lowercased() == colorHex.lowercased() ? 3 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Icono")
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(modelo.ajustes?.iconos ?? [], id: \.clave) { opcion in
                        Button { icono = opcion.clave } label: {
                            CirculoIcono(simbolo: iconoPorNombre(opcion.clave),
                                         color: Color(hexCadena: colorHex), tamano: 42)
                                .overlay(Circle().stroke(KipColor.accent,
                                                         lineWidth: icono == opcion.clave ? 2 : 0))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Tipo")
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                HStack(spacing: 8) {
                    ForEach([("gasto", "Gasto"), ("ingreso", "Ingreso")], id: \.0) { opcion in
                        let elegida = tipo == opcion.0
                        Button(opcion.1) { tipo = opcion.0 }
                            .font(.manrope(14, weight: .bold))
                            .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(elegida ? KipColor.accent : KipColor.card(scheme))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                if existente != nil {
                    Button("Borrar esta categoría") { confirmarBorrar = true }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(Color.red)
                }
                HStack(spacing: 12) {
                    botonContornoAjustes("Cancelar") { cerrar() }
                    BotonPrimario(texto: "Guardar") { guardar() }
                        .disabled(nombre.trimmingCharacters(in: .whitespaces).count < 2 || modelo.procesando)
                        .opacity(nombre.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)
                }
                Spacer()
            }
            .padding(20)
        }
        .background(KipColor.bg(scheme))
        .onAppear {
            if !sembrado, let existente = existente {
                sembrado = true
                nombre = existente.nombre
                colorHex = existente.color
                icono = existente.icono
                tipo = existente.tipo
            }
        }
        .alert("¿Borrar «\(existente?.nombre ?? "")»?", isPresented: $confirmarBorrar) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) {
                guard let existente = existente else { return }
                modelo.ejecutar(alExito: { cerrar() }) {
                    try await Api.borrarCategoriaPersonalizada(id: existente.id).mensaje
                }
            }
        } message: {
            Text("Los movimientos que están en esta categoría vuelven a la de su banco, y sus presupuestos y reglas se borran.")
        }
    }

    private func guardar() {
        let cuerpo: [String: Any] = [
            "nombre": nombre.trimmingCharacters(in: .whitespaces),
            "color": colorHex, "icono": icono, "tipo": tipo,
        ]
        if let existente = existente {
            modelo.ejecutar(alExito: { cerrar() }) {
                try await Api.editarCategoriaPersonalizada(id: existente.id, cuerpo: cuerpo).mensaje
            }
        } else {
            modelo.ejecutar(alExito: { cerrar() }) {
                try await Api.crearCategoriaPersonalizada(cuerpo: cuerpo).mensaje
            }
        }
    }
}

// MARK: - Reglas de movimientos

struct ReglasAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var porBorrar: ReglaMovimiento? = nil
    @State private var textoNuevo = ""
    @State private var esInterna = false
    @State private var categoriaElegida: String? = nil

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Reglas de movimientos", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Una regla busca un texto en el nombre de un comercio y le pone su categoría sola, o lo marca como movimiento interno. Así no tienes que corregir lo mismo cada mes.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                    let reglas = modelo.ajustes?.reglas ?? []
                    if reglas.isEmpty {
                        Text("Todavía no tienes reglas.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    } else {
                        ForEach(reglas) { regla in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("«\(regla.texto)»")
                                        .font(.manrope(16, weight: .bold))
                                        .foregroundStyle(KipColor.text(scheme))
                                    Text(regla.marcarInterna ? "Marcar como interno" : "Categoría: \(regla.categoriaNombre ?? "—")")
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer()
                                KipInterruptor(activo: Binding(get: { regla.activa }, set: { _ in alternar(regla) }))
                                Button { porBorrar = regla } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(Color.red)
                                }
                                .buttonStyle(.plain)
                            }
                            Divider().background(KipColor.border(scheme))
                        }
                        botonContornoAjustes("Aplicar las reglas a mis movimientos") {
                            modelo.ejecutar { try await Api.aplicarReglas().mensaje }
                        }
                    }
                    Text("Nueva regla")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.top, 8)
                    CampoKip(etiqueta: "Texto que aparece en el comercio", texto: $textoNuevo)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Es un movimiento interno")
                                .font(.manrope(16, weight: .bold))
                                .foregroundStyle(KipColor.text(scheme))
                            Text("Traspasos entre tus cuentas y pagos a tus tarjetas.")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                        }
                        Spacer()
                        KipInterruptor(activo: $esInterna)
                    }
                    if !esInterna {
                        Text("Categoría que se le pone:")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(modelo.ajustes?.colores ?? []) { color in
                                let elegida = categoriaElegida == color.clave
                                Button(color.nombre) {
                                    categoriaElegida = elegida ? nil : color.clave
                                }
                                .font(.manrope(13, weight: .bold))
                                .foregroundStyle(elegida ? KipColor.onAccent : KipColor.text(scheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(elegida ? KipColor.accent : KipColor.card(scheme))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: elegida ? 0 : 1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    BotonPrimario(texto: "Crear la regla") { crear() }
                        .disabled(modelo.procesando)
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .alert("¿Borrar esta regla?", isPresented: Binding(get: { porBorrar != nil }, set: { if !$0 { porBorrar = nil } })) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) {
                guard let regla = porBorrar else { return }
                modelo.ejecutar { try await Api.borrarRegla(id: regla.id).mensaje }
            }
        } message: {
            Text("Los movimientos que ya cambió se quedan como están.")
        }
    }

    private func alternar(_ regla: ReglaMovimiento) {
        Task {
            do {
                _ = try await Api.alternarRegla(id: regla.id)
                await modelo.recargar()
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar() }
            } catch {}
        }
    }

    private func crear() {
        let texto = textoNuevo.trimmingCharacters(in: .whitespaces)
        if texto.isEmpty {
            modelo.dialogoError = "Escribe el texto que la regla debe buscar."
            return
        }
        if !esInterna && categoriaElegida == nil {
            modelo.dialogoError = "Elige una categoría o márcala como interna."
            return
        }
        var cuerpo: [String: Any] = ["match_text": texto]
        if esInterna {
            cuerpo["mark_internal"] = true
        } else if let clave = categoriaElegida {
            cuerpo["category_key"] = clave
        }
        modelo.ejecutar(alExito: {
            textoNuevo = ""
            esInterna = false
            categoriaElegida = nil
        }) {
            try await Api.crearRegla(cuerpo: cuerpo).mensaje
        }
    }
}

// MARK: - Verificacion en dos pasos

struct SeguridadAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var paso = "inicio"
    @State private var codigo = ""
    @State private var llaveApp = ""
    @State private var passwordApagar = ""
    @State private var codigos: [String]? = nil

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Verificación en dos pasos", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Además de tu contraseña, al entrar te pedimos un código corto. Así, aunque alguien sepa tu contraseña, no puede entrar a tu cuenta.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                    contenido
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: Binding(get: { codigos != nil }, set: { _ in })) {
            hojaCodigos
        }
    }

    @ViewBuilder
    private var contenido: some View {
        let seguridad = modelo.ajustes?.seguridad
        if paso == "codigoCorreo" {
            Text("Te enviamos un código a tu correo. Escríbelo aquí:")
                .font(.manrope(15))
                .foregroundStyle(KipColor.text(scheme))
            CampoKip(etiqueta: "Código del correo", texto: $codigo, tecladoNumero: true)
            BotonPrimario(texto: "Confirmar y activar") {
                if codigo.isEmpty {
                    modelo.dialogoError = "Escribe el código que te llegó."
                    return
                }
                confirmar { try await Api.seguridadCorreoConfirmar(codigo: codigo) }
            }
            .disabled(codigo.isEmpty || modelo.procesando)
            .opacity(codigo.isEmpty ? 0.5 : 1)
            Button("Cancelar") { paso = "inicio"; codigo = "" }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.gradientEnd)
        } else if paso == "codigoApp" {
            Text("Guarda esta llave en tu app de códigos (como Google Authenticator) y escribe el código de 6 números que te muestre:")
                .font(.manrope(15))
                .foregroundStyle(KipColor.text(scheme))
            HStack {
                Text(llaveApp)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Button("Copiar") { UIPasteboard.general.string = llaveApp }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
            }
            CampoKip(etiqueta: "Código de la app", texto: $codigo, tecladoNumero: true)
            BotonPrimario(texto: "Confirmar y activar") {
                if codigo.isEmpty {
                    modelo.dialogoError = "Escribe el código de tu app."
                    return
                }
                confirmar { try await Api.seguridadAppConfirmar(codigo: codigo) }
            }
            .disabled(codigo.count < 6 || modelo.procesando)
            .opacity(codigo.count < 6 ? 0.5 : 1)
            Button("Cancelar") { paso = "inicio"; codigo = "" }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.gradientEnd)
        } else if seguridad?.activa == true {
            Text(seguridad?.metodo == "app" ? "Está activa con tu app de códigos." : "Está activa con códigos a tu correo.")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            botonContornoAjustes("Nuevos códigos de recuperación") {
                confirmar { try await Api.seguridadRegenerar() }
            }
            Divider().background(KipColor.border(scheme))
            Text("Apagar la verificación")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text("Te pedimos tu contraseña para confirmar que eres tú.")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            CampoKip(etiqueta: "Tu contraseña", texto: $passwordApagar, esContrasena: true)
            botonContornoAjustes("Apagar la verificación") {
                modelo.ejecutar(alExito: { passwordApagar = "" }) {
                    try await Api.seguridadDesactivar(password: passwordApagar).mensaje
                }
            }
            .disabled(passwordApagar.isEmpty || modelo.procesando)
            .opacity(passwordApagar.isEmpty ? 0.5 : 1)
        } else {
            if seguridad?.pendiente == true {
                Text("Tienes una activación a medias. Empieza de nuevo con una de las dos formas:")
                    .font(.manrope(15))
                    .foregroundStyle(Color.red)
            }
            Text("Elige cómo quieres recibir tu código:")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            BotonPrimario(texto: "Por correo") {
                iniciar {
                    let r = try await Api.seguridadCorreoIniciar()
                    paso = "codigoCorreo"
                    codigo = ""
                    return r.mensaje
                }
            }
            botonContornoAjustes("Con una app de códigos") {
                iniciar {
                    let r = try await Api.seguridadAppIniciar()
                    llaveApp = r.llave ?? ""
                    paso = "codigoApp"
                    codigo = ""
                    return r.mensaje
                }
            }
        }
    }

    private var hojaCodigos: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Guarda estos códigos")
                .font(.manrope(20, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Text("Son tus códigos de recuperación: si un día no puedes recibir el código de verificación, con uno de estos entras. Se muestran una sola vez.")
                .font(.manrope(15))
                .foregroundStyle(KipColor.textSecondary(scheme))
            ForEach(codigos ?? [], id: \.self) { codigoRecuperacion in
                Text(codigoRecuperacion)
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
            }
            BotonPrimario(texto: "Ya los guardé") { codigos = nil }
            Button("Copiar") {
                UIPasteboard.general.string = (codigos ?? []).joined(separator: "\n")
            }
            .font(.manrope(15, weight: .bold))
            .foregroundStyle(KipColor.gradientEnd)
            Spacer()
        }
        .padding(20)
        .background(KipColor.bg(scheme))
        .interactiveDismissDisabled(true)
    }

    private func iniciar(_ trabajo: @escaping () async throws -> String?) {
        if modelo.procesando { return }
        modelo.procesando = true
        Task {
            do {
                let mensaje = try await trabajo()
                modelo.procesando = false
                modelo.dialogoExito = mensaje ?? "Listo."
            } catch let e as ApiError {
                modelo.procesando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.dialogoError = e.errorDescription
            } catch {
                modelo.procesando = false
                modelo.dialogoError = "No se pudo completar la acción."
            }
        }
    }

    private func confirmar(_ trabajo: @escaping () async throws -> SeguridadConfirmada) {
        if modelo.procesando { return }
        modelo.procesando = true
        Task {
            do {
                let r = try await trabajo()
                modelo.procesando = false
                paso = "inicio"
                codigo = ""
                codigos = r.codigosRecuperacion
                await modelo.recargar()
            } catch let e as ApiError {
                modelo.procesando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.dialogoError = e.errorDescription
            } catch {
                modelo.procesando = false
                modelo.dialogoError = "No se pudo confirmar el código. Intenta de nuevo."
            }
        }
    }
}

// MARK: - Conecta tu asistente

struct AsistenteAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var porRevocar: LlaveAsistente? = nil
    @State private var nombreNueva = ""
    @State private var llaveNueva: String? = nil

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Conecta tu asistente", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Una llave permite que un asistente de inteligencia artificial consulte tus datos de Kipwallet: saldos, movimientos y tu plan de deudas. Solo puede leer, nunca mover dinero ni cambiar nada. Tú creas la llave aquí y puedes revocarla cuando quieras.")
                        .font(.manrope(15))
                        .foregroundStyle(KipColor.text(scheme))
                    let llaves = modelo.ajustes?.asistente?.llaves ?? []
                    if llaves.isEmpty {
                        Text("No tienes llaves activas.")
                            .font(.manrope(15))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                    } else {
                        ForEach(llaves) { llave in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(llave.nombre.isEmpty ? "Sin nombre" : llave.nombre)
                                        .font(.manrope(16, weight: .bold))
                                        .foregroundStyle(KipColor.text(scheme))
                                    Text(detalleLlave(llave))
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                                Spacer()
                                Button("Revocar") { porRevocar = llave }
                                    .font(.manrope(15, weight: .bold))
                                    .foregroundStyle(Color.red)
                            }
                            Divider().background(KipColor.border(scheme))
                        }
                    }
                    Text("Nueva llave")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .padding(.top, 8)
                    CampoKip(etiqueta: "Nombre (opcional)", texto: $nombreNueva)
                    BotonPrimario(texto: "Crear la llave") { crear() }
                        .disabled(modelo.procesando)
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .alert("¿Revocar esta llave?", isPresented: Binding(get: { porRevocar != nil }, set: { if !$0 { porRevocar = nil } })) {
            Button("Cancelar", role: .cancel) {}
            Button("Revocar", role: .destructive) {
                guard let llave = porRevocar else { return }
                modelo.ejecutar { try await Api.revocarLlaveAsistente(id: llave.id).mensaje }
            }
        } message: {
            Text("El asistente que la use dejará de poder consultar tus datos.")
        }
        .sheet(isPresented: Binding(get: { llaveNueva != nil }, set: { _ in })) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tu llave nueva")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Text("Esta llave se muestra una sola vez. Cópiala ahora y guárdala en un lugar seguro.")
                    .font(.manrope(15))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Text(llaveNueva ?? "")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.text(scheme))
                BotonPrimario(texto: "Ya la guardé") { llaveNueva = nil }
                Button("Copiar") { UIPasteboard.general.string = llaveNueva ?? "" }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
                Spacer()
            }
            .padding(20)
            .background(KipColor.bg(scheme))
            .interactiveDismissDisabled(true)
        }
    }

    private func detalleLlave(_ llave: LlaveAsistente) -> String {
        var texto = "Creada: \(llave.creada ?? "")"
        if let uso = llave.ultimoUso { texto += " · Último uso: \(uso)" }
        return texto
    }

    private func crear() {
        if modelo.procesando { return }
        modelo.procesando = true
        Task {
            do {
                let nombre = nombreNueva.trimmingCharacters(in: .whitespaces)
                let r = try await Api.crearLlaveAsistente(nombre: nombre.isEmpty ? nil : nombre)
                modelo.procesando = false
                nombreNueva = ""
                llaveNueva = r.llave
                await modelo.recargar()
            } catch let e as ApiError {
                modelo.procesando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.dialogoError = e.errorDescription
            } catch {
                modelo.procesando = false
                modelo.dialogoError = "No se pudo crear la llave. Intenta de nuevo."
            }
        }
    }
}

// MARK: - Cambiar mi contrasena

struct ContrasenaAjustesView: View {
    @Environment(\.colorScheme) private var scheme
    @ObservedObject var modelo: AjustesModelo
    var alVolver: () -> Void = {}
    @State private var actual = ""
    @State private var nueva = ""
    @State private var confirmacion = ""

    var body: some View {
        FondoSeccionAjustes {
            CabeceraSeccionAjustes(titulo: "Cambiar mi contraseña", alVolver: alVolver)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    CampoKip(etiqueta: "Contraseña actual", texto: $actual, esContrasena: true)
                    CampoKip(etiqueta: "Contraseña nueva", texto: $nueva, esContrasena: true)
                    CampoKip(etiqueta: "Repite la nueva", texto: $confirmacion, esContrasena: true)
                    if !nueva.isEmpty && !confirmacion.isEmpty && nueva != confirmacion {
                        Text("Las dos contraseñas nuevas no coinciden.")
                            .font(.manrope(14))
                            .foregroundStyle(Color.red)
                    }
                    BotonPrimario(texto: "Guardar la contraseña nueva") {
                        modelo.ejecutar(alExito: alVolver) {
                            try await Api.guardarContrasena(actual: actual, nueva: nueva, confirmacion: confirmacion).mensaje
                        }
                    }
                    .disabled(!habilitado || modelo.procesando)
                    .opacity(habilitado ? 1 : 0.5)
                    Color.clear.frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private var habilitado: Bool {
        !actual.isEmpty && !nueva.isEmpty && nueva == confirmacion
    }
}
