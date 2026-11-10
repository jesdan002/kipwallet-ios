import SwiftUI

// El detalle de una categoria de Gastos (CategoriaDetalleScreen.kt):
// barras de 6 meses, anillo de presupuesto, movimientos del mes con
// filtros y el total al pie. "Editar presupuesto" navega a la pantalla
// Presupuesto con la clave a editar (la pila vive en AppPrincipalView).

@MainActor
final class CategoriaDetalleModelo: ObservableObject {
    @Published var datos: CategoriaDetalleRespuesta? = nil
    @Published var cargando = false
    @Published var errorTexto: String? = nil
    @Published var mes: String
    @Published var orden = "fecha"
    @Published var cuentas: Set<Int> = []
    @Published var montoMin: Double? = nil
    @Published var montoMax: Double? = nil
    @Published var errorExportar: String? = nil

    let clave: String

    init(clave: String) {
        self.clave = clave
        let formato = DateFormatter()
        formato.calendar = Calendar(identifier: .gregorian)
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.dateFormat = "yyyy-MM"
        self.mes = formato.string(from: Date())
    }

    func query(incluirOrden: Bool) -> [(String, String)] {
        var q: [(String, String)] = [("mes", mes)]
        if incluirOrden { q.append(("orden", orden)) }
        if !cuentas.isEmpty {
            q.append(("cuentas", cuentas.sorted().map(String.init).joined(separator: ",")))
        }
        if let minimo = montoMin { q.append(("monto_min", String(minimo))) }
        if let maximo = montoMax { q.append(("monto_max", String(maximo))) }
        return q
    }

    func cargar() async {
        cargando = true
        errorTexto = nil
        do {
            datos = try await Api.categoriaDetalle(clave: clave, query: query(incluirOrden: true))
            cargando = false
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
        } catch {
            errorTexto = "Algo salió mal. Intenta de nuevo."
            cargando = false
        }
    }

    func exportar() async {
        do {
            let csv = try await Api.exportarCategoria(clave: clave, query: query(incluirOrden: false))
            compartirTexto(csv, nombreArchivo: "gastos-\(clave)-\(mes).csv")
        } catch let e as ApiError {
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorExportar = e.errorDescription
        } catch {
            errorExportar = "No se pudo exportar."
        }
    }
}

struct CategoriaDetalleView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @StateObject private var modelo: CategoriaDetalleModelo
    var alAbrirFicha: (Int) -> Void = { _ in }
    /// Navega a Presupuesto con la clave a editar: la pantalla destino
    /// abre directa la hoja de edicion del tope de esta categoria.
    var alEditarPresupuesto: (String) -> Void = { _ in }
    @State private var hojaFiltros = false

    init(clave: String, alAbrirFicha: @escaping (Int) -> Void = { _ in },
         alEditarPresupuesto: @escaping (String) -> Void = { _ in }) {
        _modelo = StateObject(wrappedValue: CategoriaDetalleModelo(clave: clave))
        self.alAbrirFicha = alAbrirFicha
        self.alEditarPresupuesto = alEditarPresupuesto
    }

    var body: some View {
        EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: modelo.datos != nil) {
            if let datos = modelo.datos {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let errorExp = modelo.errorExportar {
                            Text(errorExp)
                                .font(.manrope(14))
                                .foregroundStyle(Color.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                        }
                        Text(esMesActual(datos) ? "Este mes" : datos.mesEtiqueta)
                            .font(.manrope(20, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 4)
                        if !datos.barras.isEmpty { barras(datos) }
                        bloquePresupuesto(datos)
                        Text("Movimientos de \(datos.mesEtiqueta)")
                            .font(.manrope(16, weight: .bold))
                            .foregroundStyle(KipColor.text(scheme))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                        if datos.movimientos.isEmpty {
                            Text("No hay movimientos en este mes.")
                                .font(.manrope(14))
                                .foregroundStyle(KipColor.textSecondary(scheme))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(datos.movimientos) { fila in
                                Button { alAbrirFicha(fila.id) } label: {
                                    HStack(spacing: 12) {
                                        CirculoComercio(nombre: fila.comercio, tamano: 42, logoUrl: fila.logoUrl)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(fila.comercio)
                                                .font(.manrope(16, weight: .bold))
                                                .foregroundStyle(KipColor.text(scheme))
                                                .lineLimit(1)
                                            Text(subtituloFila(fila))
                                                .font(.manrope(14))
                                                .foregroundStyle(KipColor.textSecondary(scheme))
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
                                Divider().background(KipColor.border(scheme)).padding(.leading, 70)
                            }
                            HStack {
                                Text("Total de movimientos")
                                    .font(.manrope(16, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                Text("\(datos.totalTransacciones?.totalTexto ?? "") · \(datos.totalTransacciones?.cantidad ?? 0)")
                                    .font(.manrope(16, weight: .bold))
                                    .foregroundStyle(KipColor.text(scheme))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        Color.clear.frame(height: 24)
                    }
                }
                .refreshable { await modelo.cargar() }
            }
        } reintentar: {
            Task { await modelo.cargar() }
        }
        .navigationTitle(Text(tituloCabecera))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 10) {
                    if let info = modelo.datos?.categoria {
                        CirculoIcono(simbolo: iconoDeCategoria(clave: info.clave, icono: info.icono),
                                     color: colorDeCategoria(hex: info.color, clave: info.clave), tamano: 36)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Exportar transacciones") { Task { await modelo.exportar() } }
                    Button("Filtrar y ordenar") { hojaFiltros = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                }
            }
        }
        .task { await modelo.cargar() }
        .sheet(isPresented: $hojaFiltros) {
            FiltrosCategoriaDetalleView(modelo: modelo)
        }
    }

    private var tituloCabecera: String {
        modelo.datos?.categoria?.nombre ?? "Categoría"
    }

    private func esMesActual(_ datos: CategoriaDetalleRespuesta) -> Bool {
        let formato = DateFormatter()
        formato.calendar = Calendar(identifier: .gregorian)
        formato.locale = Locale(identifier: "en_US_POSIX")
        formato.dateFormat = "yyyy-MM"
        return datos.mes == formato.string(from: Date())
    }

    private func subtituloFila(_ fila: FilaCategoriaMov) -> String {
        var texto = fechaCorta(fila.fecha)
        if let nombre = fila.cuenta?.nombre, !nombre.isEmpty {
            texto += " · \(nombre)"
        }
        return texto
    }

    private func barras(_ datos: CategoriaDetalleRespuesta) -> some View {
        let maximo = max(datos.barras.compactMap { $0.total }.max() ?? 0, 0.01)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(datos.barras, id: \.mes) { barra in
                let elegida = barra.esElegido == true
                Button {
                    if let mes = barra.mes {
                        modelo.mes = mes
                        Task { await modelo.cargar() }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Text(barra.totalTexto ?? "")
                            .font(.manrope(11, weight: .heavy))
                            .foregroundStyle(elegida ? KipColor.text(scheme) : KipColor.textSecondary(scheme))
                            .lineLimit(1)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(elegida ? KipColor.gradientEnd : KipColor.elevated(scheme))
                            .frame(height: 6 + 82 * CGFloat((barra.total ?? 0) / maximo))
                        Text(String((barra.etiqueta ?? "").prefix(3)))
                            .font(.manrope(12, weight: .semibold))
                            .foregroundStyle(elegida ? KipColor.text(scheme) : KipColor.textSecondary(scheme))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 150, alignment: .bottom)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func bloquePresupuesto(_ datos: CategoriaDetalleRespuesta) -> some View {
        if let presupuesto = datos.presupuesto {
            let pasado = presupuesto.pasado == true
            let colorCategoria = colorDeCategoria(hex: datos.categoria?.color, clave: datos.categoria?.clave)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(KipColor.border(scheme), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: min(max((presupuesto.porcentaje ?? 0) / 100, 0), 1))
                            .stroke(pasado ? Color.red : colorCategoria, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: iconoDeCategoria(clave: datos.categoria?.clave, icono: datos.categoria?.icono))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(colorCategoria)
                    }
                    .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pasado ? "Te pasaste por" : "Te quedan")
                            .font(.manrope(14))
                            .foregroundStyle(KipColor.textSecondary(scheme))
                        Text(pasado ? dinero(abs(presupuesto.diferencia ?? 0)) : (presupuesto.diferenciaTexto ?? ""))
                            .font(.manrope(24, weight: .heavy))
                            .foregroundStyle(pasado ? Color.red : KipColor.text(scheme))
                        Button("Editar presupuesto") { alEditarPresupuesto(modelo.clave) }
                            .font(.manrope(15, weight: .bold))
                            .foregroundStyle(KipColor.gradientEnd)
                    }
                    Spacer()
                }
                Text("Gastaste \(presupuesto.gastadoTexto ?? "") de tu presupuesto de \(presupuesto.limiteTexto ?? "").")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("No tienes presupuesto para esta categoría.")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                Button("Poner presupuesto") { alEditarPresupuesto(modelo.clave) }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Hoja de filtros del detalle

struct FiltrosCategoriaDetalleView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: CategoriaDetalleModelo
    @State private var cuentasBorrador: Set<Int>
    @State private var desdeTexto: String
    @State private var hastaTexto: String
    @State private var opciones: OpcionesMovimientos? = nil

    init(modelo: CategoriaDetalleModelo) {
        self.modelo = modelo
        _cuentasBorrador = State(initialValue: modelo.cuentas)
        _desdeTexto = State(initialValue: modelo.montoMin.map { numeroSinCeros($0) } ?? "")
        _hastaTexto = State(initialValue: modelo.montoMax.map { numeroSinCeros($0) } ?? "")
    }

    private let ordenes: [(String, String)] = [
        ("fecha", "Más recientes primero"), ("fecha_asc", "Más antiguos primero"),
        ("monto_desc", "Mayor monto primero"), ("monto_asc", "Menor monto primero"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ordenes, id: \.0) { opcion in
                        Button {
                            modelo.orden = opcion.0
                            Task { await modelo.cargar() }
                        } label: {
                            HStack {
                                Text(opcion.1)
                                    .font(.manrope(16))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                if modelo.orden == opcion.0 {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(KipColor.gradientEnd)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(KipColor.bg(scheme))
                    }
                } header: {
                    Text("ORDEN")
                        .font(.manrope(14, weight: .bold))
                }
                Section {
                    ForEach(opciones?.cuentas ?? [], id: \.id) { cuenta in
                        let elegida = cuentasBorrador.contains(cuenta.id ?? -1)
                        Button {
                            if let id = cuenta.id {
                                if elegida { cuentasBorrador.remove(id) } else { cuentasBorrador.insert(id) }
                            }
                        } label: {
                            HStack {
                                Text(etiquetaCuenta(cuenta))
                                    .font(.manrope(15))
                                    .foregroundStyle(KipColor.text(scheme))
                                Spacer()
                                if elegida {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(KipColor.gradientEnd)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(KipColor.bg(scheme))
                    }
                } header: {
                    Text("CUENTAS")
                        .font(.manrope(14, weight: .bold))
                }
                Section {
                    HStack(spacing: 12) {
                        CampoTextoPlano(texto: $desdeTexto, placeholder: "Desde $")
                        CampoTextoPlano(texto: $hastaTexto, placeholder: "Hasta $")
                    }
                    .listRowBackground(KipColor.bg(scheme))
                } header: {
                    Text("MONTO")
                        .font(.manrope(14, weight: .bold))
                }
                Section {
                    Button("Aplicar") {
                        modelo.cuentas = cuentasBorrador
                        modelo.montoMin = Double(desdeTexto.replacingOccurrences(of: ",", with: "."))
                        modelo.montoMax = Double(hastaTexto.replacingOccurrences(of: ",", with: "."))
                        cerrar()
                        Task { await modelo.cargar() }
                    }
                    .font(.manrope(16, weight: .bold))
                    .foregroundStyle(KipColor.gradientEnd)
                    .listRowBackground(KipColor.bg(scheme))
                    Button("Limpiar filtros") {
                        cuentasBorrador = []
                        desdeTexto = ""
                        hastaTexto = ""
                        modelo.cuentas = []
                        modelo.montoMin = nil
                        modelo.montoMax = nil
                        cerrar()
                        Task { await modelo.cargar() }
                    }
                    .font(.manrope(15, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .listRowBackground(KipColor.bg(scheme))
                }
            }
            .listStyle(.plain)
            .navigationTitle(Text("Filtrar y ordenar"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
        .task {
            if opciones == nil {
                opciones = try? await Api.opcionesMovimientos()
            }
        }
    }

    private func etiquetaCuenta(_ cuenta: CuentaOpcion) -> String {
        [cuenta.banco, cuenta.nombre, cuenta.mascara.map { "••••\($0)" }]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

/// Un numero sin ceros sobrantes ("25.0" -> "25"), como la Android al
/// precargar los campos del editor.
func numeroSinCeros(_ valor: Double) -> String {
    if valor == valor.rounded() { return String(Int(valor)) }
    return String(valor)
}
