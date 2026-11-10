import Foundation

enum ApiError: Error {
    case sinConexion
    case sesionTerminada
    case mensaje(String)
    case respuestaInvalida
}

extension ApiError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .sinConexion: return "No hubo conexión. Revisa tu internet e intenta de nuevo."
        case .sesionTerminada: return "Tu sesión terminó. Vuelve a entrar."
        case .mensaje(let texto): return texto
        case .respuestaInvalida: return "El servidor no respondió. Intenta de nuevo."
        }
    }
}

/// Resultado del paso 1 del acceso, como en la Android.
enum ResultadoLogin {
    case sesionIniciada
    case faltaMfa(reto: String, metodo: String)
}

/// La puerta de la app a la API del servidor: la misma base y las mismas
/// rutas que usa la app Android. El token viaja en el encabezado
/// Authorization y lo pone esta clase, nunca las pantallas.
enum Api {
    static let base = "https://app.kipwallet.com/"

    private static var sesion: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }

    private static let decodificador: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    static func login(correo: String, contrasena: String) async throws -> ResultadoLogin {
        let r: RespuestaLogin = try await post("api/v1/login", cuerpo: [
            "email": correo.trimmingCharacters(in: .whitespaces),
            "password": contrasena,
        ], respaldo: "Revisa tu correo y tu contraseña.")
        return try interpretar(r)
    }

    static func registro(nombre: String, correo: String, contrasena: String, acepta: Bool) async throws -> ResultadoLogin {
        let r: RespuestaLogin = try await post("api/v1/registro", cuerpo: [
            "name": nombre,
            "email": correo.trimmingCharacters(in: .whitespaces),
            "password": contrasena,
            "password_confirmation": contrasena,
            "acepta_terminos": acepta,
        ], respaldo: "No se pudo crear tu cuenta. Revisa los datos.")
        return try interpretar(r)
    }

    static func confirmarMfa(reto: String, codigo: String) async throws -> ResultadoLogin {
        let r: RespuestaLogin = try await post("api/v1/login/mfa", cuerpo: [
            "reto": reto,
            "codigo": codigo,
        ], respaldo: "Ese código no es válido. Intenta de nuevo.")
        return try interpretar(r)
    }

    static func olvideContrasena(correo: String) async throws -> String {
        let r: MensajeRespuesta = try await post("api/v1/contrasena/olvide", cuerpo: [
            "email": correo.trimmingCharacters(in: .whitespaces),
        ], respaldo: "No se pudo enviar el enlace. Intenta de nuevo.")
        return r.mensaje ?? "Listo. Revisa tu correo."
    }

    static func panel() async throws -> Panel {
        try await get("api/v1/panel", respaldo: "No se pudo cargar tu Panel. Intenta de nuevo.")
    }

    /// El flujo de tu dinero de otro mes (las flechas de la tarjeta del
    /// Panel): devuelve nil si ese mes no tuvo ingresos.
    static func flujoDelMes(_ mes: String) async throws -> Sankey? {
        let respuesta: FlujoMesRespuesta = try await get("api/v1/panel/flujo" + sufijoQuery([("mes", mes)]),
                                                         respaldo: "No se pudo cargar el flujo de ese mes.")
        return respuesta.flujo
    }

    static func logout() async {
        // Baja del push (en iOS el registro APNs llega en la Fase 2; sin
        // token registrado no hay nada que dar de baja) y logout remoto.
        _ = try? await postCrudo("api/v1/logout")
    }

    // MARK: - Movimientos

    static func movimientos(query: [(String, String)]) async throws -> MovimientosRespuesta {
        try await get("api/v1/movimientos" + sufijoQuery(query), respaldo: "No se pudieron cargar tus movimientos.")
    }

    static func opcionesMovimientos() async throws -> OpcionesMovimientos {
        try await get("api/v1/movimientos/opciones", respaldo: "No se pudieron cargar las opciones.")
    }

    static func fichaMovimiento(id: Int) async throws -> FichaMovimientoRespuesta {
        try await get("api/v1/movimientos/\(id)", respaldo: "No se pudo cargar el movimiento.")
    }

    static func guardarMovimiento(id: Int, cuerpo: [String: Any]) async throws -> GuardarMovimientoRespuesta {
        try await metodo("PATCH", "api/v1/movimientos/\(id)", cuerpo: cuerpo, respaldo: "No se pudieron guardar los cambios.")
    }

    static func historialComercio(comercio: String) async throws -> HistorialComercio {
        try await get("api/v1/movimientos/historial" + sufijoQuery([("comercio", comercio)]), respaldo: "No se pudo cargar el historial.")
    }

    static func reportarMovimiento(id: Int, cuerpo: [String: Any]) async throws -> MensajeRespuesta {
        try await post("api/v1/movimientos/\(id)/reportar", cuerpo: cuerpo, respaldo: "No se pudo enviar tu reporte.")
    }

    static func dividirMovimiento(id: Int, partes: [[String: Any]]) async throws -> GuardarMovimientoRespuesta {
        try await post("api/v1/movimientos/\(id)/dividir", cuerpo: ["partes": partes], respaldo: "No se pudo dividir el cargo.")
    }

    static func reunirMovimiento(id: Int) async throws -> GuardarMovimientoRespuesta {
        try await post("api/v1/movimientos/\(id)/reunir", cuerpo: [:], respaldo: "No se pudo reunir el cargo.")
    }

    static func loteMovimientos(cuerpo: [String: Any]) async throws -> LoteRespuesta {
        try await post("api/v1/movimientos/lote", cuerpo: cuerpo, respaldo: "No se pudieron actualizar los movimientos.")
    }

    static func agregarMovimiento(cuerpo: [String: Any]) async throws -> ManualRespuesta {
        try await post("api/v1/movimientos", cuerpo: cuerpo, respaldo: "No se pudo agregar el movimiento.")
    }

    static func exportarMovimientos(query: [(String, String)]) async throws -> String {
        try await getTexto("api/v1/movimientos/exportar" + sufijoQuery(query), respaldo: "No se pudo exportar.")
    }

    // MARK: - Gastos

    static func gastos(query: [(String, String)]) async throws -> GastosRespuesta {
        try await get("api/v1/gastos" + sufijoQuery(query), respaldo: "No se pudieron cargar tus gastos.")
    }

    static func categoriaDetalle(clave: String, query: [(String, String)]) async throws -> CategoriaDetalleRespuesta {
        let claveRuta = clave.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clave
        return try await get("api/v1/gastos/categoria/\(claveRuta)" + sufijoQuery(query), respaldo: "No se pudo cargar el detalle.")
    }

    static func exportarCategoria(clave: String, query: [(String, String)]) async throws -> String {
        let claveRuta = clave.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? clave
        return try await getTexto("api/v1/gastos/categoria/\(claveRuta)/exportar" + sufijoQuery(query), respaldo: "No se pudo exportar.")
    }

    // MARK: - Presupuesto (pantalla) y Pronostico

    /// La pantalla Presupuesto del mes pedido; sin mes, el mes actual
    /// del servidor. Toda escritura devuelve la pantalla entera
    /// recalculada y el modelo la sustituye (no hay DTO de mensaje).
    static func presupuesto(mes: String?) async throws -> PresupuestoPantalla {
        var query: [(String, String)] = []
        if let mes = mes { query.append(("mes", mes)) }
        return try await get("api/v1/presupuesto" + sufijoQuery(query), respaldo: "No se pudo cargar tu presupuesto.")
    }

    /// Fija el tope de una categoria. Claves en espanol (categoria, mes,
    /// limite): el contrato web (category/month/limit_amount) da 422.
    /// El tope es unico por categoria para todos los meses; `mes` solo
    /// elige el mes del payload que se devuelve.
    static func guardarPresupuesto(categoria: String, mes: String, limite: Double) async throws -> PresupuestoPantalla {
        try await post("api/v1/presupuesto", cuerpo: [
            "categoria": categoria, "mes": mes, "limite": limite,
        ], respaldo: "No se pudo guardar el presupuesto. Intenta de nuevo.")
    }

    static func guardarPlanPresupuesto(mes: String, ingreso: Double) async throws -> PresupuestoPantalla {
        try await post("api/v1/presupuesto/plan", cuerpo: [
            "mes": mes, "ingreso_esperado": ingreso,
        ], respaldo: "No se pudo guardar el ingreso esperado. Intenta de nuevo.")
    }

    static func reiniciarPresupuesto(mes: String) async throws -> PresupuestoPantalla {
        try await post("api/v1/presupuesto/reiniciar", cuerpo: [
            "mes": mes,
        ], respaldo: "No se pudo empezar de nuevo. Intenta de nuevo.")
    }

    /// Quita el tope de una categoria: el path lleva el id del Budget
    /// (fila.id), NO la clave de la categoria. Ojo: la respuesta puede
    /// traer el payload de otro mes (el del budget borrado, §1.9 del mapa).
    static func quitarPresupuesto(id: Int) async throws -> PresupuestoPantalla {
        try await metodo("DELETE", "api/v1/presupuesto/\(id)", cuerpo: nil, respaldo: "No se pudo quitar el presupuesto. Intenta de nuevo.")
    }

    /// El Pronostico: `plan` se manda como entero 1/0, igual que Retrofit
    /// en la Android, y `meses` solo vale 3 o 6 (otro valor el servidor
    /// lo convierte a 3).
    static func pronostico(meses: Int, plan: Bool) async throws -> Pronostico {
        try await get("api/v1/pronostico" + sufijoQuery([("meses", String(meses)), ("plan", plan ? "1" : "0")]),
                      respaldo: "No se pudo cargar tu pronóstico. Intenta de nuevo.")
    }

    // MARK: - Deudas

    static func deudas() async throws -> DeudasRespuesta {
        try await get("api/v1/deudas", respaldo: "No se pudieron cargar tus deudas. Intenta de nuevo.")
    }

    static func simularDeudas(extra: Double, estrategia: String) async throws -> SimulacionDeudas {
        try await post("api/v1/deudas/simular", cuerpo: ["extra": extra, "estrategia": estrategia], respaldo: "No se pudo hacer la simulación. Intenta de nuevo.")
    }

    static func guardarPlanDeudas(extra: Double, estrategia: String) async throws -> DeudasRespuesta {
        try await post("api/v1/deudas/plan", cuerpo: ["extra": extra, "estrategia": estrategia], respaldo: "No se pudo guardar tu plan. Intenta de nuevo.")
    }

    static func guardarDatosDeuda(id: Int, cuerpo: [String: Any]) async throws -> GuardarDatosDeudaRespuesta {
        try await metodo("PATCH", "api/v1/deudas/\(id)", cuerpo: cuerpo, respaldo: "No se pudieron guardar los datos. Intenta de nuevo.")
    }

    // MARK: - Recurrentes y calendario

    static func recurrentes(orden: String) async throws -> RecurrentesRespuesta {
        try await get("api/v1/recurrentes" + sufijoQuery([("orden", orden)]), respaldo: "No se pudieron cargar tus cargos recurrentes. Intenta de nuevo.")
    }

    static func calendario(mes: String?) async throws -> CalendarioRespuesta {
        var query: [(String, String)] = []
        if let mes = mes { query.append(("mes", mes)) }
        return try await get("api/v1/calendario" + sufijoQuery(query), respaldo: "No se pudo cargar tu calendario. Intenta de nuevo.")
    }

    // MARK: - Mas, membresia y Ajustes

    static func mas() async throws -> MasRespuesta {
        try await get("api/v1/mas", respaldo: "No se pudo cargar tu membresía.")
    }

    static func membresia() async throws -> MembresiaGestion {
        try await get("api/v1/membresia", respaldo: "No se pudo cargar tu membresía.")
    }

    static func ajustes() async throws -> AjustesRespuesta {
        try await get("api/v1/ajustes", respaldo: "No se pudieron cargar tus ajustes.")
    }

    static func cuentasEstado() async throws -> CuentasEstadoRespuesta {
        try await get("api/v1/cuentas", respaldo: "No se pudieron cargar tus cuentas.")
    }

    static func guardarPerfil(nombre: String) async throws -> MensajeRespuesta {
        try await metodo("PUT", "api/v1/ajustes/perfil", cuerpo: ["nombre": nombre], respaldo: "No se pudo guardar el nombre. Intenta de nuevo.")
    }

    static func cambiarCorreo(correo: String) async throws -> MensajeRespuesta {
        try await metodo("PUT", "api/v1/ajustes/correo", cuerpo: ["correo": correo], respaldo: "No se pudo cambiar tu correo. Intenta de nuevo.")
    }

    static func guardarContrasena(actual: String, nueva: String, confirmacion: String) async throws -> MensajeRespuesta {
        try await metodo("PUT", "api/v1/ajustes/contrasena", cuerpo: [
            "actual": actual, "nueva": nueva, "nueva_confirmation": confirmacion,
        ], respaldo: "No se pudo cambiar la contraseña. Intenta de nuevo.")
    }

    static func guardarCiclo(cuerpo: [String: Any]) async throws -> MensajeRespuesta {
        try await metodo("PUT", "api/v1/ajustes/ciclo", cuerpo: cuerpo, respaldo: "No se pudo guardar tu ciclo de pago. Intenta de nuevo.")
    }

    static func guardarNotificaciones(_ prefs: NotificacionesPrefs) async throws -> MensajeRespuesta {
        let datos = try JSONEncoder().encode(prefs)
        let objeto = (try? JSONSerialization.jsonObject(with: datos)) as? [String: Any] ?? [:]
        return try await metodo("PUT", "api/v1/ajustes/notificaciones", cuerpo: objeto, respaldo: "No se pudieron guardar tus notificaciones. Intenta de nuevo.")
    }

    static func guardarColorCategoria(clave: String, color: String?, restablecer: Bool) async throws -> MensajeRespuesta {
        var cuerpo: [String: Any] = ["category_key": clave]
        if restablecer {
            cuerpo["restablecer"] = true
        } else if let color = color {
            cuerpo["color"] = color
        }
        return try await metodo("PUT", "api/v1/ajustes/categoria-color", cuerpo: cuerpo, respaldo: "No se pudo guardar el color. Intenta de nuevo.")
    }

    static func crearCategoriaPersonalizada(cuerpo: [String: Any]) async throws -> CategoriaCreada {
        try await post("api/v1/ajustes/categorias-personalizadas", cuerpo: cuerpo, respaldo: "No se pudo crear la categoría. Intenta de nuevo.")
    }

    static func editarCategoriaPersonalizada(id: Int, cuerpo: [String: Any]) async throws -> MensajeRespuesta {
        try await metodo("PUT", "api/v1/ajustes/categorias-personalizadas/\(id)", cuerpo: cuerpo, respaldo: "No se pudo guardar la categoría. Intenta de nuevo.")
    }

    static func borrarCategoriaPersonalizada(id: Int) async throws -> MensajeRespuesta {
        try await metodo("DELETE", "api/v1/ajustes/categorias-personalizadas/\(id)", cuerpo: nil, respaldo: "No se pudo borrar la categoría. Intenta de nuevo.")
    }

    static func crearRegla(cuerpo: [String: Any]) async throws -> ReglaCreada {
        try await post("api/v1/ajustes/reglas", cuerpo: cuerpo, respaldo: "No se pudo crear la regla. Intenta de nuevo.")
    }

    static func aplicarReglas() async throws -> MensajeRespuesta {
        try await post("api/v1/ajustes/reglas/aplicar", cuerpo: [:], respaldo: "No se pudieron aplicar las reglas. Intenta de nuevo.")
    }

    static func alternarRegla(id: Int) async throws -> AlternarRegla {
        try await post("api/v1/ajustes/reglas/\(id)/alternar", cuerpo: [:], respaldo: "No se pudo cambiar la regla. Intenta de nuevo.")
    }

    static func borrarRegla(id: Int) async throws -> MensajeRespuesta {
        try await metodo("DELETE", "api/v1/ajustes/reglas/\(id)", cuerpo: nil, respaldo: "No se pudo eliminar la regla. Intenta de nuevo.")
    }

    static func seguridadCorreoIniciar() async throws -> SeguridadIniciar {
        try await post("api/v1/ajustes/seguridad/correo/iniciar", cuerpo: [:], respaldo: "No se pudo enviar el código. Intenta de nuevo.")
    }

    static func seguridadCorreoConfirmar(codigo: String) async throws -> SeguridadConfirmada {
        try await post("api/v1/ajustes/seguridad/correo/confirmar", cuerpo: ["codigo": codigo], respaldo: "No se pudo confirmar el código. Intenta de nuevo.")
    }

    static func seguridadAppIniciar() async throws -> SeguridadIniciar {
        try await post("api/v1/ajustes/seguridad/app/iniciar", cuerpo: [:], respaldo: "No se pudo preparar la llave. Intenta de nuevo.")
    }

    static func seguridadAppConfirmar(codigo: String) async throws -> SeguridadConfirmada {
        try await post("api/v1/ajustes/seguridad/app/confirmar", cuerpo: ["codigo": codigo], respaldo: "No se pudo confirmar el código. Intenta de nuevo.")
    }

    static func seguridadRegenerar() async throws -> SeguridadConfirmada {
        try await post("api/v1/ajustes/seguridad/recuperacion/regenerar", cuerpo: [:], respaldo: "No se pudieron generar los códigos. Intenta de nuevo.")
    }

    static func seguridadDesactivar(password: String) async throws -> MensajeRespuesta {
        try await post("api/v1/ajustes/seguridad/desactivar", cuerpo: ["password": password], respaldo: "No se pudo apagar la verificación. Intenta de nuevo.")
    }

    static func crearLlaveAsistente(nombre: String?) async throws -> LlaveCreada {
        var cuerpo: [String: Any] = [:]
        if let nombre = nombre { cuerpo["name"] = nombre }
        return try await post("api/v1/ajustes/asistente/token", cuerpo: cuerpo, respaldo: "No se pudo crear la llave. Intenta de nuevo.")
    }

    static func revocarLlaveAsistente(id: Int) async throws -> MensajeRespuesta {
        try await metodo("DELETE", "api/v1/ajustes/asistente/token/\(id)", cuerpo: nil, respaldo: "No se pudo revocar la llave. Intenta de nuevo.")
    }

    static func exportarDatos(tipo: String, mes: String?) async throws -> UrlRespuesta {
        var cuerpo: [String: Any] = ["tipo": tipo]
        if let mes = mes { cuerpo["mes"] = mes }
        return try await post("api/v1/datos/exportar", cuerpo: cuerpo, respaldo: "No se pudo preparar la descarga.")
    }

    static func sincronizarCuenta(id: Int) async throws -> MensajeOk {
        try await post("api/v1/cuentas/\(id)/sincronizar", cuerpo: [:], respaldo: "No se pudo pedir la sincronización. Intenta de nuevo.")
    }

    static func subirFoto(datos: Data) async throws -> FotoRespuesta {
        var req = URLRequest(url: URL(string: base + "api/v1/yo/foto")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let limite = "KipFrontera\(UUID().uuidString)"
        req.setValue("multipart/form-data; boundary=\(limite)", forHTTPHeaderField: "Content-Type")
        var cuerpo = Data()
        cuerpo.append("--\(limite)\r\n".data(using: .utf8)!)
        cuerpo.append("Content-Disposition: form-data; name=\"foto\"; filename=\"foto.jpg\"\r\n".data(using: .utf8)!)
        cuerpo.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        cuerpo.append(datos)
        cuerpo.append("\r\n--\(limite)--\r\n".data(using: .utf8)!)
        req.httpBody = cuerpo
        return try await ejecutar(req, respaldo: "No se pudo subir la foto. Intenta de nuevo.")
    }

    static func mejorar(tipo: String, intentabas: String, mensaje: String, correo: String?) async throws -> MensajeOk {
        var cuerpo: [String: Any] = [
            "tipo": tipo,
            "intentabas": intentabas,
            "mensaje": mensaje,
            "origen": "app-mas",
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        ]
        if let correo = correo, !correo.isEmpty { cuerpo["correo"] = correo }
        return try await post("api/v1/mejorar", cuerpo: cuerpo, respaldo: "No se pudo enviar tu mensaje. Intenta de nuevo.")
    }

    // MARK: - Notificaciones

    static func notificaciones() async throws -> CentroNotificaciones {
        try await get("api/v1/notificaciones", respaldo: "No se pudieron cargar tus notificaciones.")
    }

    static func leerNotificacion(id: Int) async throws -> MensajeOk {
        try await post("api/v1/notificaciones/\(id)/leer", cuerpo: [:], respaldo: "No se pudo marcar como leída.")
    }

    static func leerTodasNotificaciones() async throws -> MensajeOk {
        try await post("api/v1/notificaciones/leer-todas", cuerpo: [:], respaldo: "No se pudieron marcar como leídas.")
    }

    // MARK: - Patrimonio

    static func patrimonio(rango: String) async throws -> PatrimonioDto {
        try await get("api/v1/patrimonio" + sufijoQuery([("rango", rango)]), respaldo: "No se pudo cargar tu patrimonio. Intenta de nuevo.")
    }

    /// Las mutaciones de Patrimonio devuelven la foto completa con el
    /// rango forzado a 3M: el modelo adopta la respuesta tal cual.
    static func agregarBien(cuerpo: [String: Any]) async throws -> PatrimonioDto {
        try await post("api/v1/patrimonio/bienes", cuerpo: cuerpo, respaldo: "No se pudo agregar. Intenta de nuevo.")
    }

    static func editarBien(id: Int, cuerpo: [String: Any]) async throws -> PatrimonioDto {
        try await metodo("PUT", "api/v1/patrimonio/bienes/\(id)", cuerpo: cuerpo, respaldo: "No se pudo guardar. Intenta de nuevo.")
    }

    static func borrarBien(id: Int) async throws -> PatrimonioDto {
        try await metodo("DELETE", "api/v1/patrimonio/bienes/\(id)", cuerpo: nil, respaldo: "No se pudo eliminar. Intenta de nuevo.")
    }

    // MARK: - Metas

    static func metas() async throws -> MetasDto {
        try await get("api/v1/metas", respaldo: "No se pudieron cargar tus metas. Intenta de nuevo.")
    }

    /// La respuesta de las mutaciones de Metas se descarta: el modelo
    /// recarga el GET completo, como en la Android.
    static func crearMeta(cuerpo: [String: Any]) async throws -> MetaRespuestaDto {
        try await post("api/v1/metas", cuerpo: cuerpo, respaldo: "No se pudo crear la meta. Intenta de nuevo.")
    }

    static func editarMeta(id: Int, cuerpo: [String: Any]) async throws -> MetaRespuestaDto {
        try await metodo("PUT", "api/v1/metas/\(id)", cuerpo: cuerpo, respaldo: "No se pudieron guardar los cambios. Intenta de nuevo.")
    }

    static func eliminarMeta(id: Int) async throws -> MensajeOk {
        try await metodo("DELETE", "api/v1/metas/\(id)", cuerpo: nil, respaldo: "No se pudo eliminar la meta. Intenta de nuevo.")
    }

    /// Archivar es un toggle del servidor: va sin cuerpo.
    static func archivarMeta(id: Int) async throws -> MetaRespuestaDto {
        try await metodo("POST", "api/v1/metas/\(id)/archivar", cuerpo: nil, respaldo: "No se pudo archivar la meta. Intenta de nuevo.")
    }

    static func aportarMeta(id: Int, cuerpo: [String: Any]) async throws -> MetaRespuestaDto {
        try await post("api/v1/metas/\(id)/movimientos", cuerpo: cuerpo, respaldo: "No se pudo registrar el movimiento. Intenta de nuevo.")
    }

    // MARK: - Transporte generico

    private static func sufijoQuery(_ pares: [(String, String)]) -> String {
        let partes = pares.compactMap { (clave, valor) -> String? in
            guard let k = clave.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let v = valor.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return "\(k)=\(v)"
        }
        return partes.isEmpty ? "" : "?" + partes.joined(separator: "&")
    }

    private static func metodo<T: Decodable>(_ nombre: String, _ ruta: String, cuerpo: [String: Any]?, respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = nombre
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let cuerpo = cuerpo {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        }
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func getTexto(_ ruta: String, respaldo: String) async throws -> String {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: req)
        } catch {
            throw ApiError.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ApiError.respuestaInvalida }
        if http.statusCode == 401 { throw ApiError.sesionTerminada }
        if !(200..<300).contains(http.statusCode) {
            throw ApiError.mensaje(mensajeDeError(datos) ?? respaldo)
        }
        return String(data: datos, encoding: .utf8) ?? ""
    }

    // MARK: - Interpretacion y transporte

    private static func interpretar(_ r: RespuestaLogin) throws -> ResultadoLogin {
        if r.mfaRequired == true, let reto = r.reto {
            return .faltaMfa(reto: reto, metodo: r.metodo ?? "correo")
        }
        guard let token = r.token else { throw ApiError.respuestaInvalida }
        Sesion.token = token
        if let correo = r.usuario?.email { Sesion.correo = correo }
        return .sesionIniciada
    }

    private static func get<T: Decodable>(_ ruta: String, respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func post<T: Decodable>(_ ruta: String, cuerpo: [String: Any], respaldo: String) async throws -> T {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: cuerpo)
        return try await ejecutar(req, respaldo: respaldo)
    }

    private static func postCrudo(_ ruta: String) async throws {
        var req = URLRequest(url: URL(string: base + ruta)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = Sesion.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        _ = try await sesion.data(for: req)
    }

    private static func ejecutar<T: Decodable>(_ req: URLRequest, respaldo: String) async throws -> T {
        let datos: Data
        let respuesta: URLResponse
        do {
            (datos, respuesta) = try await sesion.data(for: req)
        } catch {
            throw ApiError.sinConexion
        }
        guard let http = respuesta as? HTTPURLResponse else { throw ApiError.respuestaInvalida }
        if http.statusCode == 401 { throw ApiError.sesionTerminada }
        if !(200..<300).contains(http.statusCode) {
            throw ApiError.mensaje(mensajeDeError(datos) ?? respaldo)
        }
        do {
            return try decodificador.decode(T.self, from: datos)
        } catch {
            throw ApiError.respuestaInvalida
        }
    }

    /// El mensaje de error que manda el servidor (Laravel) para mostrarlo
    /// tal cual, en lenguaje llano — la misma regla que la app Android.
    private static func mensajeDeError(_ datos: Data) -> String? {
        guard let objeto = try? JSONSerialization.jsonObject(with: datos) as? [String: Any] else { return nil }
        return objeto["message"] as? String
    }
}
