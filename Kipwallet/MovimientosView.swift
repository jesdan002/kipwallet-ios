import SwiftUI

// La pantalla Movimientos: la lista completa de lo que entra y sale,
// espejo de la Android (MovimientosScreen.kt): buscador con debounce,
// hub de filtros, agrupado por mes, paginacion infinita, seleccion en
// lote y alta manual. La ficha se abre con onAbrirFicha.

/// El estado de filtros de la lista (FiltrosMovimiento de la Android).
struct FiltrosMovimiento: Equatable {
    var cuentaId: Int? = nil
    var categoria: String? = nil
    var periodo: String = "todo"
    var monto: String = "todos"
    var orden: String = "fecha"
    var etiqueta: String? = nil
    var revisada: String? = nil
    var desde: String? = nil
    var hasta: String? = nil

    /// Dimensiones activas (el orden no cuenta), como la Android.
    var activos: Int {
        var n = 0
        if cuentaId != nil { n += 1 }
        if categoria != nil { n += 1 }
        if periodo != "todo" { n += 1 }
        if monto != "todos" { n += 1 }
        if etiqueta != nil { n += 1 }
        if revisada != nil { n += 1 }
        if desde != nil || hasta != nil { n += 1 }
        return n
    }
}

let OPCIONES_PERIODO: [(String, String)] = [
    ("todo", "Todo el tiempo"), ("este_mes", "Este mes"),
    ("mes_pasado", "Mes pasado"), ("ultimos_30", "Últimos 30 días"),
]
let OPCIONES_MONTO: [(String, String)] = [
    ("todos", "Todos"), ("menos20", "Gastos menores de $20"),
    ("20a100", "De $20 a $100"), ("mas100", "Más de $100"), ("ingresos", "Solo ingresos"),
]
let OPCIONES_ORDEN: [(String, String)] = [
    ("fecha", "Fecha · más recientes primero"), ("fecha_asc", "Fecha · más antiguas primero"),
    ("monto_desc", "Monto · de mayor a menor"), ("monto_asc", "Monto · de menor a mayor"),
]
let OPCIONES_REVISION: [(String, String)] = [
    ("todas", "Todos"), ("revisadas", "Solo revisados"), ("sin_revisar", "Sin revisar"),
]

@MainActor
final class MovimientosModelo: ObservableObject {
    @Published var filas: [MovimientoFila] = []
    @Published var conteo = 0
    @Published var totalGastoTexto = ""
    @Published var gruposMes: [GrupoMesMov] = []
    @Published var hayMas = false
    @Published var cargando = false
    @Published var cargandoMas = false
    @Published var errorTexto: String? = nil
    @Published var mensajeAccion: String? = nil
    @Published var mensajeError = false
    @Published var opciones: OpcionesMovimientos? = nil

    var filtros = FiltrosMovimiento()
    var busqueda = ""
    private var pagina = 1
    private var generacion = 0

    func query(incluirPagina: Bool) -> [(String, String)] {
        var q: [(String, String)] = []
        let texto = busqueda.trimmingCharacters(in: .whitespaces)
        if !texto.isEmpty { q.append(("q", texto)) }
        if let c = filtros.cuentaId { q.append(("cuenta", String(c))) }
        if let c = filtros.categoria { q.append(("categoria", c)) }
        q.append(("periodo", filtros.periodo))
        q.append(("monto", filtros.monto))
        q.append(("orden", filtros.orden))
        if let e = filtros.etiqueta { q.append(("etiqueta", e)) }
        if let r = filtros.revisada { q.append(("revisada", r)) }
        if let d = filtros.desde { q.append(("desde", d)) }
        if let h = filtros.hasta { q.append(("hasta", h)) }
        if incluirPagina { q.append(("page", String(pagina))) }
        return q
    }

    func cargarPrimera() async {
        generacion += 1
        let gen = generacion
        pagina = 1
        cargando = true
        errorTexto = nil
        do {
            let r = try await Api.movimientos(query: query(incluirPagina: true))
            guard gen == generacion else { return }
            filas = r.movimientos
            conteo = r.conteo ?? r.movimientos.count
            totalGastoTexto = r.totalGastoTexto ?? ""
            gruposMes = r.gruposMes
            hayMas = r.paginacion?.hayMas ?? false
            cargando = false
        } catch let e as ApiError {
            guard gen == generacion else { return }
            if case .sesionTerminada = e { Sesion.cerrar(); return }
            errorTexto = e.errorDescription
            cargando = false
        } catch {
            guard gen == generacion else { return }
            errorTexto = "Algo salió mal. Intenta de nuevo."
            cargando = false
        }
    }

    func cargarMas() async {
        guard hayMas, !cargandoMas, !cargando else { return }
        let gen = generacion
        cargandoMas = true
        pagina += 1
        do {
            let r = try await Api.movimientos(query: query(incluirPagina: true))
            guard gen == generacion else { return }
            filas.append(contentsOf: r.movimientos)
            hayMas = r.paginacion?.hayMas ?? false
            cargandoMas = false
        } catch {
            guard gen == generacion else { return }
            pagina -= 1
            cargandoMas = false
        }
    }

    func cargarOpciones() async {
        if opciones != nil { return }
        if let r = try? await Api.opcionesMovimientos() { opciones = r }
    }

    func mostrarMensaje(_ texto: String, esError: Bool) {
        mensajeAccion = texto
        mensajeError = esError
    }
}

struct MovimientosView: View {
    @Environment(\.colorScheme) private var scheme
    var alAbrirFicha: (Int) -> Void = { _ in }
    @StateObject private var modelo = MovimientosModelo()
    @State private var busquedaTexto = ""
    @State private var tareaBusqueda: Task<Void, Never>? = nil
    @State private var mostrarFiltros = false
    @State private var mostrarAgregar = false
    @State private var seleccionando = false
    @State private var seleccionados: Set<Int> = []
    @State private var mostrarSelectorLote = false

    var body: some View {
        EstadoCarga(cargando: modelo.cargando, error: modelo.errorTexto, listo: !modelo.filas.isEmpty || (modelo.errorTexto == nil && !modelo.cargando)) {
            contenido
        } reintentar: {
            Task { await modelo.cargarPrimera() }
        }
        .task {
            if modelo.filas.isEmpty { await modelo.cargarPrimera() }
        }
        .sheet(isPresented: $mostrarFiltros) {
            FiltrosMovimientosView(modelo: modelo)
        }
        .sheet(isPresented: $mostrarAgregar) {
            AgregarMovimientoView(modelo: modelo)
        }
        .sheet(isPresented: $mostrarSelectorLote) {
            SelectorCategoriaLoteView(modelo: modelo, ids: Array(seleccionados)) {
                seleccionando = false
                seleccionados = []
            }
        }
    }

    private var contenido: some View {
        VStack(spacing: 0) {
            barraSuperior
            buscador
            if modelo.filtros.activos > 0 && !seleccionando { filaFiltrosActivos }
            if let mensaje = modelo.mensajeAccion { filaMensaje(mensaje) }
            if !modelo.totalGastoTexto.isEmpty && !seleccionando { filaTotales }
            lista
            if seleccionando { barraLote }
        }
        .background(KipColor.bg(scheme))
    }

    private var barraSuperior: some View {
        HStack {
            if seleccionando {
                Button {
                    seleccionando = false
                    seleccionados = []
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(KipColor.text(scheme))
                }
                .buttonStyle(.plain)
                Text("\(seleccionados.count) seleccionados")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                    .padding(.leading, 8)
            } else {
                Text("Movimientos")
                    .font(.manrope(20, weight: .bold))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Menu {
                    Button("Edición en lote") {
                        seleccionando = true
                        seleccionados = []
                    }
                    Button("Exportar a CSV") { exportar() }
                    Button("Agregar movimiento") {
                        Task { await modelo.cargarOpciones() }
                        mostrarAgregar = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(KipColor.text(scheme))
                        .frame(width: 40, height: 40)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var buscador: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KipColor.textSecondary(scheme))
            TextField("Busca un comercio", text: $busquedaTexto)
                .font(.manrope(16))
                .foregroundStyle(KipColor.text(scheme))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: busquedaTexto) { _ in
                    tareaBusqueda?.cancel()
                    tareaBusqueda = Task {
                        try? await Task.sleep(nanoseconds: 450_000_000)
                        guard !Task.isCancelled else { return }
                        modelo.busqueda = busquedaTexto
                        await modelo.cargarPrimera()
                    }
                }
            Button {
                Task { await modelo.cargarOpciones() }
                mostrarFiltros = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundStyle(KipColor.text(scheme))
                    .overlay(alignment: .topTrailing) {
                        if modelo.filtros.activos > 0 {
                            Text("\(modelo.filtros.activos)")
                                .font(.manrope(10, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(KipColor.gradientEnd))
                                .offset(x: 6, y: -6)
                        }
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(KipColor.card(scheme))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KipColor.border(scheme), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var filaFiltrosActivos: some View {
        HStack(spacing: 10) {
            Text(modelo.filtros.activos == 1 ? "1 filtro activo" : "\(modelo.filtros.activos) filtros activos")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
            Button("Limpiar") {
                var f = FiltrosMovimiento()
                f.orden = modelo.filtros.orden
                modelo.filtros = f
                Task { await modelo.cargarPrimera() }
            }
            .font(.manrope(14, weight: .bold))
            .foregroundStyle(KipColor.text(scheme))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private func filaMensaje(_ texto: String) -> some View {
        HStack {
            Text(texto)
                .font(.manrope(14))
                .foregroundStyle(modelo.mensajeError ? Color.red : KipColor.gradientEnd)
            Spacer()
            Button("OK") { modelo.mensajeAccion = nil }
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var filaTotales: some View {
        HStack {
            Text("Gasto total: \(modelo.totalGastoTexto)")
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            Text("\(modelo.conteo) movimientos")
                .font(.manrope(14))
                .foregroundStyle(KipColor.textSecondary(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var vacio: some View {
        VStack {
            Spacer()
            Text(textoVacio)
                .font(.manrope(16))
                .foregroundStyle(KipColor.textSecondary(scheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var textoVacio: String {
        if !busquedaTexto.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No hay movimientos que coincidan con tu búsqueda."
        }
        if modelo.filtros.activos > 0 { return "No hay movimientos con esos filtros." }
        return "Todavía no hay movimientos."
    }

    private var lista: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if modelo.filas.isEmpty && !modelo.cargando {
                    vacio.frame(height: 220)
                } else if agrupado {
                    ForEach(gruposOrdenados, id: \.mes) { grupo in
                        cabeceraMes(grupo)
                        ForEach(grupo.filas) { mov in
                            filaConDivisor(mov)
                        }
                    }
                } else {
                    ForEach(modelo.filas) { mov in
                        filaConDivisor(mov)
                    }
                }
                if modelo.cargandoMas {
                    ProgressView().tint(KipColor.accent).padding(20)
                } else if modelo.hayMas && !modelo.filas.isEmpty {
                    Button("Cargar más") { Task { await modelo.cargarMas() } }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                        .padding(16)
                }
                Color.clear.frame(height: 16)
                    .onAppear {
                        if modelo.filas.count >= 21 { Task { await modelo.cargarMas() } }
                    }
            }
        }
        .refreshable { await modelo.cargarPrimera() }
    }

    private var agrupado: Bool {
        modelo.filtros.orden == "fecha" || modelo.filtros.orden == "fecha_asc"
    }

    private struct GrupoLocal {
        let mes: String
        let etiqueta: String
        let totalTexto: String
        let filas: [MovimientoFila]
    }

    private var gruposOrdenados: [GrupoLocal] {
        var orden: [String] = []
        var mapa: [String: [MovimientoFila]] = [:]
        for mov in modelo.filas {
            let mes = String(mov.fecha.prefix(7))
            if mapa[mes] == nil { orden.append(mes) }
            mapa[mes, default: []].append(mov)
        }
        return orden.map { mes in
            let info = modelo.gruposMes.first { $0.mes == mes }
            let etiqueta = info?.etiqueta ?? nombreMesLocal(mes)
            return GrupoLocal(mes: mes, etiqueta: etiqueta, totalTexto: info?.totalGastoTexto ?? "", filas: mapa[mes] ?? [])
        }
    }

    private func cabeceraMes(_ grupo: GrupoLocal) -> some View {
        HStack {
            Text(grupo.etiqueta)
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            Spacer()
            if !grupo.totalTexto.isEmpty {
                Text("\(grupo.totalTexto) de gasto")
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }

    private func filaConDivisor(_ mov: MovimientoFila) -> some View {
        VStack(spacing: 0) {
            FilaMovimiento(mov: mov,
                           seleccionado: seleccionando ? seleccionados.contains(mov.id) : nil,
                           alSeleccionar: { alternar(mov.id) }) {
                if seleccionando {
                    alternar(mov.id)
                } else {
                    alAbrirFicha(mov.id)
                }
            }
            .onLongPressGesture {
                if !seleccionando {
                    seleccionando = true
                    seleccionados = [mov.id]
                }
            }
            Divider()
                .background(KipColor.border(scheme))
                .padding(.leading, 74)
        }
    }

    private func alternar(_ id: Int) {
        if seleccionados.contains(id) { seleccionados.remove(id) } else { seleccionados.insert(id) }
    }

    private var barraLote: some View {
        VStack(spacing: 0) {
            Divider().background(KipColor.border(scheme))
            HStack(spacing: 10) {
                botonLote("Categoría") {
                    Task { await modelo.cargarOpciones() }
                    mostrarSelectorLote = true
                }
                botonLote("Interna") { aplicarLote(interna: true) }
                botonLote("No interna") { aplicarLote(interna: false) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(KipColor.bg(scheme))
    }

    private func botonLote(_ texto: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(KipColor.border(scheme), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(seleccionados.isEmpty)
        .opacity(seleccionados.isEmpty ? 0.5 : 1)
    }

    private func aplicarLote(interna: Bool) {
        let ids = Array(seleccionados)
        Task {
            do {
                let r = try await Api.loteMovimientos(cuerpo: ["ids": ids, "interna": interna])
                modelo.mostrarMensaje(r.mensaje ?? "Se actualizaron \(r.actualizados ?? 0) movimientos.", esError: false)
                seleccionando = false
                seleccionados = []
                await modelo.cargarPrimera()
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.mostrarMensaje(e.errorDescription ?? "Algo salió mal. Intenta de nuevo.", esError: true)
            }
        }
    }

    private func exportar() {
        Task {
            do {
                let csv = try await Api.exportarMovimientos(query: modelo.query(incluirPagina: false))
                compartirTexto(csv, nombreArchivo: "movimientos.csv")
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.mostrarMensaje(e.errorDescription ?? "Algo salió mal. Intenta de nuevo.", esError: true)
            }
        }
    }
}

/// "Noviembre de 2026" desde "2026-11" (nombreMes de la Android).
func nombreMesLocal(_ mes: String) -> String {
    let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    let partes = mes.split(separator: "-")
    guard partes.count == 2, let m = Int(partes[1]), (1...12).contains(m) else { return mes }
    let nombre = meses[m - 1]
    return nombre.prefix(1).uppercased() + nombre.dropFirst() + " de \(partes[0])"
}

/// Comparte un texto (CSV) con la hoja de compartir del sistema.
func compartirTexto(_ texto: String, nombreArchivo: String) {
    let carpeta = FileManager.default.temporaryDirectory
    let url = carpeta.appendingPathComponent(nombreArchivo)
    try? texto.data(using: .utf8)?.write(to: url)
    let controlador = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    guard let escena = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let raiz = escena.windows.first?.rootViewController else { return }
    var tope = raiz
    while let presentado = tope.presentedViewController { tope = presentado }
    controlador.popoverPresentationController?.sourceView = tope.view
    tope.present(controlador, animated: true)
}

// MARK: - Hub de filtros

struct FiltrosMovimientosView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: MovimientosModelo
    @State private var borrador: FiltrosMovimiento
    @State private var pestana = 0
    @State private var seccion: String? = nil
    @State private var etiquetaTexto = ""

    init(modelo: MovimientosModelo) {
        self.modelo = modelo
        _borrador = State(initialValue: modelo.filtros)
        _etiquetaTexto = State(initialValue: modelo.filtros.etiqueta ?? "")
    }

    var body: some View {
        NavigationStack {
            Group {
                if let seccion = seccion {
                    contenidoSeccion(seccion)
                } else {
                    raiz
                }
            }
            .navigationTitle(Text(seccionTitulo))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(seccion == nil ? "Cancelar" : "Volver") {
                        if seccion == nil { cerrar() } else { seccion = nil }
                    }
                }
            }
        }
    }

    private var seccionTitulo: String {
        switch seccion {
        case "cuentas": return "Cuentas"
        case "categorias": return "Categorías"
        case "fechas": return "Fechas"
        case "monto": return "Tipo y monto"
        case "etiquetas": return "Etiquetas"
        case "revision": return "Revisión"
        default: return "Filtrar y ordenar"
        }
    }

    private var raiz: some View {
        VStack(spacing: 0) {
            Picker("", selection: $pestana) {
                Text("Filtrar").tag(0)
                Text("Ordenar").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(16)
            if pestana == 0 {
                List {
                    filaHub("Cuentas", valor: valorCuenta) { seccion = "cuentas" }
                    filaHub("Categorías", valor: valorCategoria) { seccion = "categorias" }
                    filaHub("Fechas", valor: valorPeriodo) { seccion = "fechas" }
                    filaHub("Tipo y monto", valor: valorMonto) { seccion = "monto" }
                    filaHub("Etiquetas", valor: borrador.etiqueta ?? "Todas") { seccion = "etiquetas" }
                    filaHub("Revisión", valor: valorRevision) { seccion = "revision" }
                }
                .listStyle(.plain)
            } else {
                List {
                    ForEach(OPCIONES_ORDEN, id: \.0) { opcion in
                        radioFila(titulo: opcion.1, elegido: borrador.orden == opcion.0) {
                            borrador.orden = opcion.0
                        }
                    }
                }
                .listStyle(.plain)
            }
            VStack(spacing: 10) {
                Button {
                    modelo.filtros = borrador
                    cerrar()
                    Task { await modelo.cargarPrimera() }
                } label: {
                    Text("Aplicar filtros")
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(KipColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Button("Limpiar filtros") {
                    var f = FiltrosMovimiento()
                    f.orden = borrador.orden
                    borrador = f
                    etiquetaTexto = ""
                }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
            }
            .padding(16)
        }
        .background(KipColor.bg(scheme))
    }

    private func filaHub(_ titulo: String, valor: String, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(titulo)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                Text(valor)
                    .font(.manrope(14))
                    .foregroundStyle(KipColor.textSecondary(scheme))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KipColor.textSecondary(scheme))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(KipColor.bg(scheme))
    }

    private func radioFila(titulo: String, elegido: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            HStack {
                Text(titulo)
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                Spacer()
                if elegido {
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

    private var valorCuenta: String {
        guard let id = borrador.cuentaId, let cuenta = modelo.opciones?.cuentas.first(where: { $0.id == id }) else { return "Todas" }
        let partes = [cuenta.banco, cuenta.nombre].compactMap { $0 }.filter { !$0.isEmpty }
        return partes.isEmpty ? "Todas" : partes.joined(separator: " · ")
    }

    private var valorCategoria: String {
        guard let clave = borrador.categoria else { return "Todas" }
        return modelo.opciones?.categorias.first { $0.clave == clave }?.nombre ?? clave
    }

    private var valorPeriodo: String {
        if borrador.desde != nil || borrador.hasta != nil { return "Rango exacto" }
        return OPCIONES_PERIODO.first { $0.0 == borrador.periodo }?.1 ?? "Todo el tiempo"
    }

    private var valorMonto: String {
        OPCIONES_MONTO.first { $0.0 == borrador.monto }?.1 ?? "Todos"
    }

    private var valorRevision: String {
        switch borrador.revisada {
        case "revisadas": return "Solo revisados"
        case "sin_revisar": return "Sin revisar"
        default: return "Todos"
        }
    }

    @ViewBuilder
    private func contenidoSeccion(_ clave: String) -> some View {
        switch clave {
        case "cuentas":
            List {
                radioFila(titulo: "Todas las cuentas", elegido: borrador.cuentaId == nil) {
                    borrador.cuentaId = nil
                    seccion = nil
                }
                ForEach(modelo.opciones?.cuentas ?? [], id: \.id) { cuenta in
                    Button {
                        borrador.cuentaId = cuenta.id
                        seccion = nil
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cuenta.nombre ?? "")
                                    .font(.manrope(16))
                                    .foregroundStyle(KipColor.text(scheme))
                                let sub = [cuenta.banco, cuenta.mascara.map { "••••\($0)" }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                                if !sub.isEmpty {
                                    Text(sub)
                                        .font(.manrope(14))
                                        .foregroundStyle(KipColor.textSecondary(scheme))
                                }
                            }
                            Spacer()
                            if borrador.cuentaId == cuenta.id {
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
            }
            .listStyle(.plain)
        case "categorias":
            List {
                radioFila(titulo: "Todas las categorías", elegido: borrador.categoria == nil) {
                    borrador.categoria = nil
                    seccion = nil
                }
                ForEach(modelo.opciones?.categorias ?? [], id: \.clave) { categoria in
                    Button {
                        borrador.categoria = categoria.clave
                        seccion = nil
                    } label: {
                        HStack(spacing: 12) {
                            CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                         color: colorDeCategoria(hex: categoria.color, clave: categoria.clave), tamano: 36)
                            Text(categoria.nombre ?? "")
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                            Spacer()
                            if borrador.categoria == categoria.clave {
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
            }
            .listStyle(.plain)
        case "fechas":
            List {
                ForEach(OPCIONES_PERIODO, id: \.0) { opcion in
                    radioFila(titulo: opcion.1, elegido: borrador.periodo == opcion.0 && borrador.desde == nil && borrador.hasta == nil) {
                        borrador.periodo = opcion.0
                        borrador.desde = nil
                        borrador.hasta = nil
                    }
                }
                Section {
                    DatePicker("Desde", selection: fechaBinding(\.desde), displayedComponents: .date)
                        .font(.manrope(16))
                    DatePicker("Hasta", selection: fechaBinding(\.hasta), displayedComponents: .date)
                        .font(.manrope(16))
                    if borrador.desde != nil || borrador.hasta != nil {
                        Button("Quitar el rango") {
                            borrador.desde = nil
                            borrador.hasta = nil
                        }
                        .font(.manrope(15, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                    }
                } header: {
                    Text("Rango con fechas exactas")
                        .font(.manrope(14, weight: .bold))
                }
                Section {
                    Button("Listo") { seccion = nil }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                }
            }
            .listStyle(.plain)
        case "monto":
            List {
                ForEach(OPCIONES_MONTO, id: \.0) { opcion in
                    radioFila(titulo: opcion.1, elegido: borrador.monto == opcion.0) {
                        borrador.monto = opcion.0
                        seccion = nil
                    }
                }
            }
            .listStyle(.plain)
        case "etiquetas":
            VStack(alignment: .leading, spacing: 14) {
                CampoKip(etiqueta: "Etiqueta", texto: $etiquetaTexto)
                Button("Usar esta etiqueta") {
                    let limpia = etiquetaTexto.trimmingCharacters(in: .whitespaces).lowercased()
                    borrador.etiqueta = limpia.isEmpty ? nil : limpia
                    seccion = nil
                }
                .font(.manrope(16, weight: .bold))
                .foregroundStyle(KipColor.gradientEnd)
                Button("Todas las etiquetas") {
                    borrador.etiqueta = nil
                    etiquetaTexto = ""
                    seccion = nil
                }
                .font(.manrope(15, weight: .bold))
                .foregroundStyle(KipColor.text(scheme))
                Spacer()
            }
            .padding(16)
            .background(KipColor.bg(scheme))
        case "revision":
            List {
                ForEach(OPCIONES_REVISION, id: \.0) { opcion in
                    radioFila(titulo: opcion.1, elegido: (borrador.revisada ?? "todas") == opcion.0) {
                        borrador.revisada = opcion.0 == "todas" ? nil : opcion.0
                        seccion = nil
                    }
                }
            }
            .listStyle(.plain)
        default:
            EmptyView()
        }
    }

    private func fechaBinding(_ clave: WritableKeyPath<FiltrosMovimiento, String?>) -> Binding<Date> {
        Binding(
            get: { parseFecha(borrador[keyPath: clave] ?? "") ?? Date() },
            set: { nueva in
                let formato = DateFormatter()
                formato.calendar = Calendar(identifier: .gregorian)
                formato.locale = Locale(identifier: "en_US_POSIX")
                formato.dateFormat = "yyyy-MM-dd"
                borrador[keyPath: clave] = formato.string(from: nueva)
                borrador.periodo = "todo"
            }
        )
    }
}

// MARK: - Selector de categoria del lote

struct SelectorCategoriaLoteView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: MovimientosModelo
    let ids: [Int]
    var alTerminar: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                Button("Sin categoría") { aplicar(categoria: "") }
                    .font(.manrope(16))
                    .foregroundStyle(KipColor.text(scheme))
                    .listRowBackground(KipColor.bg(scheme))
                ForEach(modelo.opciones?.categorias ?? [], id: \.clave) { categoria in
                    Button {
                        aplicar(categoria: categoria.clave)
                    } label: {
                        HStack(spacing: 12) {
                            CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                         color: colorDeCategoria(hex: categoria.color, clave: categoria.clave), tamano: 34)
                            Text(categoria.nombre ?? "")
                                .font(.manrope(16))
                                .foregroundStyle(KipColor.text(scheme))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(KipColor.bg(scheme))
                }
            }
            .listStyle(.plain)
            .navigationTitle(Text("Elige la categoría"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }

    private func aplicar(categoria: String?) {
        // En iOS se manda SIEMPRE la clave ("" = quitar la correccion):
        // la Android la omite por su serializador y el servidor no aplica
        // nada; aqui se corrige ese detalle a proposito.
        var cuerpo: [String: Any] = ["ids": ids]
        if let categoria = categoria { cuerpo["categoria"] = categoria }
        Task {
            do {
                let r = try await Api.loteMovimientos(cuerpo: cuerpo)
                modelo.mostrarMensaje(r.mensaje ?? "Se actualizaron \(r.actualizados ?? 0) movimientos.", esError: false)
                cerrar()
                alTerminar()
                await modelo.cargarPrimera()
            } catch let e as ApiError {
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                modelo.mostrarMensaje(e.errorDescription ?? "Algo salió mal. Intenta de nuevo.", esError: true)
                cerrar()
            }
        }
    }
}

// MARK: - Agregar movimiento manual

struct AgregarMovimientoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var cerrar
    @ObservedObject var modelo: MovimientosModelo
    @State private var descripcion = ""
    @State private var montoTexto = ""
    @State private var esGasto = true
    @State private var fecha = Date()
    @State private var categoriaElegida: CategoriaMov? = nil
    @State private var cuentaElegida: CuentaOpcion? = nil
    @State private var errorLocal: String? = nil
    @State private var guardando = false
    @State private var hojaCategoria = false
    @State private var hojaCuenta = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CampoKip(etiqueta: "Descripción", texto: $descripcion)
                    CampoKip(etiqueta: "Monto", texto: $montoTexto)
                    HStack(spacing: 10) {
                        chipTipo("Gasto", elegido: esGasto) { esGasto = true }
                        chipTipo("Ingreso", elegido: !esGasto) { esGasto = false }
                    }
                    DatePicker("Fecha: \(fechaLegible(isoDeFecha(fecha)))", selection: $fecha, displayedComponents: .date)
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                    Button("Categoría: \(categoriaElegida?.nombre ?? "Sin categoría")") { hojaCategoria = true }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                    Button("Cuenta: \(cuentaElegida?.nombre ?? "Sin cuenta")") { hojaCuenta = true }
                        .font(.manrope(16, weight: .bold))
                        .foregroundStyle(KipColor.gradientEnd)
                    if let errorLocal = errorLocal {
                        Text(errorLocal)
                            .font(.manrope(14))
                            .foregroundStyle(Color.red)
                    }
                    Spacer(minLength: 8)
                }
                .padding(16)
            }
            .background(KipColor.bg(scheme))
            .navigationTitle(Text("Agregar movimiento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agregar") { guardar() }
                        .disabled(guardando)
                }
            }
            .sheet(isPresented: $hojaCategoria) {
                NavigationStack {
                    List {
                        Button("Sin categoría") {
                            categoriaElegida = nil
                            hojaCategoria = false
                        }
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.text(scheme))
                        .listRowBackground(KipColor.bg(scheme))
                        ForEach(modelo.opciones?.categorias ?? [], id: \.clave) { categoria in
                            Button {
                                categoriaElegida = categoria
                                hojaCategoria = false
                            } label: {
                                HStack(spacing: 12) {
                                    CirculoIcono(simbolo: iconoDeCategoria(clave: categoria.clave, icono: categoria.icono),
                                                 color: colorDeCategoria(hex: categoria.color, clave: categoria.clave), tamano: 34)
                                    Text(categoria.nombre ?? "")
                                        .font(.manrope(16))
                                        .foregroundStyle(KipColor.text(scheme))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(KipColor.bg(scheme))
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle(Text("Elige la categoría"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $hojaCuenta) {
                NavigationStack {
                    List {
                        Button("Sin cuenta") {
                            cuentaElegida = nil
                            hojaCuenta = false
                        }
                        .font(.manrope(16))
                        .foregroundStyle(KipColor.text(scheme))
                        .listRowBackground(KipColor.bg(scheme))
                        ForEach(modelo.opciones?.cuentas ?? [], id: \.id) { cuenta in
                            Button(cuenta.nombre ?? "") {
                                cuentaElegida = cuenta
                                hojaCuenta = false
                            }
                            .font(.manrope(16))
                            .foregroundStyle(KipColor.text(scheme))
                            .listRowBackground(KipColor.bg(scheme))
                        }
                    }
                    .listStyle(.plain)
                    .navigationTitle(Text("Elige la cuenta"))
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private func chipTipo(_ texto: String, elegido: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Text(texto)
                .font(.manrope(14, weight: .bold))
                .foregroundStyle(elegido ? KipColor.onAccent : KipColor.text(scheme))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(elegido ? KipColor.accent : KipColor.card(scheme))
                .overlay(Capsule().stroke(KipColor.border(scheme), lineWidth: elegido ? 0 : 1))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func guardar() {
        let desc = descripcion.trimmingCharacters(in: .whitespaces)
        if desc.isEmpty {
            errorLocal = "Escribe una descripción."
            return
        }
        let monto = Double(montoTexto.replacingOccurrences(of: ",", with: ".")) ?? 0
        if monto <= 0 {
            errorLocal = "Escribe un monto válido, mayor que cero."
            return
        }
        errorLocal = nil
        guardando = true
        var cuerpo: [String: Any] = [
            "descripcion": desc,
            "fecha": isoDeFecha(fecha),
            "tipo": esGasto ? "gasto" : "ingreso",
            "monto": monto,
        ]
        if let clave = categoriaElegida?.clave { cuerpo["categoria"] = clave }
        if let id = cuentaElegida?.id { cuerpo["cuenta_id"] = id }
        Task {
            do {
                let r = try await Api.agregarMovimiento(cuerpo: cuerpo)
                modelo.mostrarMensaje(r.mensaje ?? "Movimiento agregado.", esError: false)
                cerrar()
                await modelo.cargarPrimera()
            } catch let e as ApiError {
                guardando = false
                if case .sesionTerminada = e { Sesion.cerrar(); return }
                errorLocal = e.errorDescription
            }
        }
    }
}

/// "yyyy-MM-dd" de una fecha del selector.
func isoDeFecha(_ fecha: Date) -> String {
    let formato = DateFormatter()
    formato.calendar = Calendar(identifier: .gregorian)
    formato.locale = Locale(identifier: "en_US_POSIX")
    formato.dateFormat = "yyyy-MM-dd"
    return formato.string(from: fecha)
}
