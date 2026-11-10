import Foundation

// Los modelos de la API v1 de Kipwallet: el MISMO contrato que consume
// la app Android (ApiModels.kt), campo por campo. El servidor manda los
// textos ya formateados ("$1,750.07") y la app los pinta tal cual.

struct Usuario: Codable {
    let nombre: String
    let email: String
    let fotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case nombre, email
        case fotoUrl = "foto_url"
    }
}

/// Respuesta de POST /login, /registro y /login/mfa.
/// - Con sesion: token y usuario.
/// - Con MFA pendiente: mfaRequired = true, reto y metodo ("correo" o "app"), sin token.
struct RespuestaLogin: Codable {
    let token: String?
    let usuario: Usuario?
    let mfaRequired: Bool?
    let reto: String?
    let metodo: String?
    let expiraEnMinutos: Int?

    enum CodingKeys: String, CodingKey {
        case token, usuario, reto, metodo
        case mfaRequired = "mfa_required"
        case expiraEnMinutos = "expira_en_minutos"
    }
}

/// Respuesta de GET api/v1/panel/flujo?mes=yyyy-MM: el flujo del mes
/// pedido, o `flujo` en null si ese mes no tuvo ingresos.
struct FlujoMesRespuesta: Codable {
    let flujo: Sankey?
}

struct MensajeRespuesta: Codable {
    let mensaje: String?
}

struct Panel: Codable {
    let patrimonioNeto: Double
    let patrimonioNetoTexto: String
    let puedesGastarHoy: Double
    let puedesGastarHoyTexto: String
    let puedesGastarCiclo: Double
    let puedesGastarCicloTexto: String
    let score: Int
    let scoreFrase: String
    let deudas: DeudasPanel
    let cuentas: [Cuenta]
    let proximos: [Proximo]
    let recientes: [Reciente]
    let configuracion: Configuracion
    let enPausa: Bool?
    let fotoUrl: String?
    let primerNombre: String?
    let gruposCuentas: [GrupoCuentas]?
    let ultimaSincronizacionTexto: String?
    let presupuesto: PresupuestoMes
    let preferencias: PreferenciasPanel
    let carrusel: Carrusel

    enum CodingKeys: String, CodingKey {
        case score, deudas, cuentas, proximos, recientes, configuracion, presupuesto, preferencias, carrusel
        case patrimonioNeto = "patrimonio_neto"
        case patrimonioNetoTexto = "patrimonio_neto_texto"
        case puedesGastarHoy = "puedes_gastar_hoy"
        case puedesGastarHoyTexto = "puedes_gastar_hoy_texto"
        case puedesGastarCiclo = "puedes_gastar_ciclo"
        case puedesGastarCicloTexto = "puedes_gastar_ciclo_texto"
        case scoreFrase = "score_frase"
        case enPausa = "en_pausa"
        case fotoUrl = "foto_url"
        case primerNombre = "primer_nombre"
        case gruposCuentas = "grupos_cuentas"
        case ultimaSincronizacionTexto = "ultima_sincronizacion_texto"
    }
}

extension Panel {
    static var vacio: Panel {
        Panel(patrimonioNeto: 0, patrimonioNetoTexto: "$0.00",
              puedesGastarHoy: 0, puedesGastarHoyTexto: "$0.00",
              puedesGastarCiclo: 0, puedesGastarCicloTexto: "$0.00",
              score: 0, scoreFrase: "",
              deudas: DeudasPanel(total: 0, totalTexto: "$0.00", cantidad: 0,
                                  pagoMinimoTotal: nil, pagoMinimoTotalTexto: nil,
                                  fechaLibertad: nil, fechaLibertadTexto: nil,
                                  estrategia: "", estrategiaTexto: ""),
              cuentas: [], proximos: [], recientes: [],
              configuracion: Configuracion(pasos: [], hechos: 0, total: 0, porcentaje: 0, completa: false),
              enPausa: false, fotoUrl: nil, primerNombre: "",
              gruposCuentas: [], ultimaSincronizacionTexto: nil,
              presupuesto: PresupuestoMes(), preferencias: PreferenciasPanel(),
              carrusel: Carrusel())
    }
}

struct DeudasPanel: Codable {
    let total: Double
    let totalTexto: String
    let cantidad: Int
    // El servidor manda null cuando ninguna deuda trae pago minimo conocido.
    let pagoMinimoTotal: Double?
    let pagoMinimoTotalTexto: String?
    let fechaLibertad: String?
    let fechaLibertadTexto: String?
    let estrategia: String
    let estrategiaTexto: String

    enum CodingKeys: String, CodingKey {
        case total, cantidad, estrategia
        case totalTexto = "total_texto"
        case pagoMinimoTotal = "pago_minimo_total"
        case pagoMinimoTotalTexto = "pago_minimo_total_texto"
        case fechaLibertad = "fecha_libertad"
        case fechaLibertadTexto = "fecha_libertad_texto"
        case estrategiaTexto = "estrategia_texto"
    }
}

struct Cuenta: Codable, Identifiable {
    let id: Int
    let banco: String
    let nombre: String
    let mascara: String?
    let saldo: Double
    let saldoTexto: String
    let tipo: String
    let subtipo: String?

    enum CodingKeys: String, CodingKey {
        case id, banco, nombre, mascara, saldo, tipo, subtipo
        case saldoTexto = "saldo_texto"
    }
}

struct Proximo: Codable, Identifiable {
    var id: String { comercio + fecha }
    let comercio: String
    let logoUrl: String?
    let monto: Double
    let montoTexto: String
    let fecha: String
    let dias: Int

    enum CodingKeys: String, CodingKey {
        case comercio, monto, fecha, dias
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
    }
}

struct Pareja: Codable {
    let etiqueta: String?
    let texto: String?
}

/// Un movimiento reciente del Panel; la pareja (fase 2 de claridad de
/// la Android) viaja opcional y la app la pinta junto a la fecha.
struct Reciente: Codable, Identifiable {
    let id: Int?
    let comercio: String
    let logoUrl: String?
    let fecha: String
    let monto: Double
    let montoTexto: String
    let categoria: String?
    let categoriaNombre: String?
    let categoriaIcono: String?
    let categoriaColor: String?
    let pareja: Pareja?

    enum CodingKeys: String, CodingKey {
        case id, comercio, fecha, monto, categoria, pareja
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
        case categoriaNombre = "categoria_nombre"
        case categoriaIcono = "categoria_icono"
        case categoriaColor = "categoria_color"
    }
}

struct PasoConfiguracion: Codable, Identifiable {
    var id: String { clave ?? etiqueta ?? UUID().uuidString }
    let clave: String?
    let etiqueta: String?
    let hecho: Bool?
}

struct Configuracion: Codable {
    let pasos: [PasoConfiguracion]
    let hechos: Int
    let total: Int
    let porcentaje: Int
    let completa: Bool

    init(pasos: [PasoConfiguracion] = [], hechos: Int = 0, total: Int = 0, porcentaje: Int = 0, completa: Bool = false) {
        self.pasos = pasos
        self.hechos = hechos
        self.total = total
        self.porcentaje = porcentaje
        self.completa = completa
    }
}

struct GrupoCuentas: Codable, Identifiable {
    var id: String { clave ?? etiqueta ?? UUID().uuidString }
    let clave: String?
    let etiqueta: String?
    let total: Double?
    let totalTexto: String?
    let esResumen: Bool?
    let cuentas: [Cuenta]?

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, total, cuentas
        case totalTexto = "total_texto"
        case esResumen = "es_resumen"
    }
}

struct PresupuestoFila: Codable, Identifiable {
    var id: String { (categoria ?? "") + (etiqueta ?? "") }
    let categoria: String?
    let categoriaIcono: String?
    let categoriaColor: String?
    let etiqueta: String?
    let gastado: Double?
    let gastadoTexto: String?
    let limite: Double?
    let limiteTexto: String?
    let porcentaje: Double?

    enum CodingKeys: String, CodingKey {
        case categoria, etiqueta, gastado, limite, porcentaje
        case categoriaIcono = "categoria_icono"
        case categoriaColor = "categoria_color"
        case gastadoTexto = "gastado_texto"
        case limiteTexto = "limite_texto"
    }
}

struct PresupuestoMes: Codable {
    let mesEtiqueta: String?
    let hayPresupuesto: Bool?
    let totalLimites: Double?
    let totalLimitesTexto: String?
    let totalGastado: Double?
    let totalGastadoTexto: String?
    let queda: Double?
    let quedaTexto: String?
    let porcentaje: Double?
    let filas: [PresupuestoFila]?

    enum CodingKeys: String, CodingKey {
        case queda, porcentaje, filas
        case mesEtiqueta = "mes_etiqueta"
        case hayPresupuesto = "hay_presupuesto"
        case totalLimites = "total_limites"
        case totalLimitesTexto = "total_limites_texto"
        case totalGastado = "total_gastado"
        case totalGastadoTexto = "total_gastado_texto"
        case quedaTexto = "queda_texto"
    }

    init(mesEtiqueta: String? = nil, hayPresupuesto: Bool? = nil, totalLimites: Double? = nil,
         totalLimitesTexto: String? = nil, totalGastado: Double? = nil, totalGastadoTexto: String? = nil,
         queda: Double? = nil, quedaTexto: String? = nil, porcentaje: Double? = nil, filas: [PresupuestoFila]? = nil) {
        self.mesEtiqueta = mesEtiqueta
        self.hayPresupuesto = hayPresupuesto
        self.totalLimites = totalLimites
        self.totalLimitesTexto = totalLimitesTexto
        self.totalGastado = totalGastado
        self.totalGastadoTexto = totalGastadoTexto
        self.queda = queda
        self.quedaTexto = quedaTexto
        self.porcentaje = porcentaje
        self.filas = filas
    }
}

struct PreferenciasPanel: Codable {
    let orden: [String]
    let ocultos: [String]

    init(orden: [String] = ["carrusel", "configuracion", "proximos", "cuentas", "recientes", "presupuesto"],
         ocultos: [String] = []) {
        self.orden = orden
        self.ocultos = ocultos
    }
}

struct Carrusel: Codable {
    let gastoMes: GastoMes
    let diaPago: DiaPago
    let patrimonio: CarruselPatrimonio
    let deudas: CarruselDeudas
    let sankey: Sankey?

    enum CodingKeys: String, CodingKey {
        case patrimonio, deudas, sankey
        case gastoMes = "gasto_mes"
        case diaPago = "dia_pago"
    }

    init(gastoMes: GastoMes = GastoMes(), diaPago: DiaPago = DiaPago(),
         patrimonio: CarruselPatrimonio = CarruselPatrimonio(),
         deudas: CarruselDeudas = CarruselDeudas(), sankey: Sankey? = nil) {
        self.gastoMes = gastoMes
        self.diaPago = diaPago
        self.patrimonio = patrimonio
        self.deudas = deudas
        self.sankey = sankey
    }
}

struct GastoMes: Codable {
    let total: Double?
    let totalTexto: String?
    let cambioPct: Double?
    let anteriorTexto: String?
    let diferenciaTexto: String?
    let serie: [Double]?
    let presupuestoTotal: Double?
    let presupuestoTotalTexto: String?

    enum CodingKeys: String, CodingKey {
        case total, serie
        case totalTexto = "total_texto"
        case cambioPct = "cambio_pct"
        case anteriorTexto = "anterior_texto"
        case diferenciaTexto = "diferencia_texto"
        case presupuestoTotal = "presupuesto_total"
        case presupuestoTotalTexto = "presupuesto_total_texto"
    }

    init(total: Double? = nil, totalTexto: String? = nil, cambioPct: Double? = nil,
         anteriorTexto: String? = nil, diferenciaTexto: String? = nil, serie: [Double]? = nil,
         presupuestoTotal: Double? = nil, presupuestoTotalTexto: String? = nil) {
        self.total = total
        self.totalTexto = totalTexto
        self.cambioPct = cambioPct
        self.anteriorTexto = anteriorTexto
        self.diferenciaTexto = diferenciaTexto
        self.serie = serie
        self.presupuestoTotal = presupuestoTotal
        self.presupuestoTotalTexto = presupuestoTotalTexto
    }
}

struct DiaPago: Codable {
    let dias: Int?
    let texto: String?

    init(dias: Int? = nil, texto: String? = nil) {
        self.dias = dias
        self.texto = texto
    }
}

struct PuntoPatrimonio: Codable {
    let fecha: String?
    let neto: Double?
}

struct CarruselPatrimonio: Codable {
    let cambioPct: Double?
    let serie: [PuntoPatrimonio]?

    enum CodingKeys: String, CodingKey {
        case serie
        case cambioPct = "cambio_pct"
    }

    init(cambioPct: Double? = nil, serie: [PuntoPatrimonio]? = nil) {
        self.cambioPct = cambioPct
        self.serie = serie
    }
}

struct SeriePunto: Codable {
    let mes: String?
    let etiqueta: String?
    let saldo: Double?
    let saldoTexto: String?

    enum CodingKeys: String, CodingKey {
        case mes, etiqueta, saldo
        case saldoTexto = "saldo_texto"
    }
}

struct CarruselDeudas: Codable {
    let serie: [SeriePunto]?
    let mesesTotal: Int?

    enum CodingKeys: String, CodingKey {
        case serie
        case mesesTotal = "meses_total"
    }

    init(serie: [SeriePunto]? = nil, mesesTotal: Int? = nil) {
        self.serie = serie
        self.mesesTotal = mesesTotal
    }
}

struct SankeyFlujo: Codable {
    let clave: String?
    let etiqueta: String?
    let monto: Double?
    let montoTexto: String?
    let pct: Double?
    let esAhorro: Bool?

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, monto, pct
        case montoTexto = "monto_texto"
        case esAhorro = "es_ahorro"
    }
}

struct Sankey: Codable {
    let ingreso: Double?
    let ingresoTexto: String?
    let mes: String?
    let mesEtiqueta: String?
    let esMesActual: Bool?
    let flujos: [SankeyFlujo]?

    enum CodingKeys: String, CodingKey {
        case ingreso, mes, flujos
        case ingresoTexto = "ingreso_texto"
        case mesEtiqueta = "mes_etiqueta"
        case esMesActual = "es_mes_actual"
    }
}

// MARK: - Fase 1: Movimientos y ficha

/// La categoria efectiva de un movimiento (CategoriaDto de la Android).
/// `clave` va opcional: en `categoria_original` el servidor la puede
/// mandar en null, y sin eso la ficha entera fallaria al decodificar.
struct CategoriaMov: Codable {
    let clave: String?
    let nombre: String?
    let icono: String?
    let tipo: String?
    let color: String?

    init(clave: String? = nil, nombre: String? = nil, icono: String? = nil, tipo: String? = nil, color: String? = nil) {
        self.clave = clave
        self.nombre = nombre
        self.icono = icono
        self.tipo = tipo
        self.color = color
    }
}

struct CuentaMov: Codable {
    let id: Int?
    let nombre: String?
    let banco: String?
    let mascara: String?

    init(id: Int? = nil, nombre: String? = nil, banco: String? = nil, mascara: String? = nil) {
        self.id = id
        self.nombre = nombre
        self.banco = banco
        self.mascara = mascara
    }
}

/// La fila de movimiento (MovimientoDto de la Android): la comparten la
/// lista, el historial y las secciones de Gastos.
struct MovimientoFila: Codable, Identifiable {
    let id: Int
    let comercio: String
    let logoUrl: String?
    let fecha: String
    let fechaTexto: String
    let monto: Double
    let montoTexto: String
    let categoria: CategoriaMov?
    let cuenta: CuentaMov?
    let esManual: Bool
    let esInterno: Bool
    let esRecurrente: Bool
    let revisada: Bool
    let pareja: Pareja?

    enum CodingKeys: String, CodingKey {
        case id, comercio, fecha, monto, categoria, cuenta, pareja
        case logoUrl = "logo_url"
        case fechaTexto = "fecha_texto"
        case montoTexto = "monto_texto"
        case esManual = "es_manual"
        case esInterno = "es_interno"
        case esRecurrente = "es_recurrente"
        case revisada
    }

    init(id: Int, comercio: String, logoUrl: String?, fecha: String, fechaTexto: String,
         monto: Double, montoTexto: String, categoria: CategoriaMov?, cuenta: CuentaMov?,
         esManual: Bool, esInterno: Bool, esRecurrente: Bool, revisada: Bool, pareja: Pareja?) {
        self.id = id
        self.comercio = comercio
        self.logoUrl = logoUrl
        self.fecha = fecha
        self.fechaTexto = fechaTexto
        self.monto = monto
        self.montoTexto = montoTexto
        self.categoria = categoria
        self.cuenta = cuenta
        self.esManual = esManual
        self.esInterno = esInterno
        self.esRecurrente = esRecurrente
        self.revisada = revisada
        self.pareja = pareja
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        comercio = try c.decode(String.self, forKey: .comercio)
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaTexto = try c.decodeIfPresent(String.self, forKey: .fechaTexto) ?? ""
        monto = try c.decode(Double.self, forKey: .monto)
        montoTexto = try c.decode(String.self, forKey: .montoTexto)
        categoria = try c.decodeIfPresent(CategoriaMov.self, forKey: .categoria)
        cuenta = try c.decodeIfPresent(CuentaMov.self, forKey: .cuenta)
        esManual = try c.decodeIfPresent(Bool.self, forKey: .esManual) ?? false
        esInterno = try c.decodeIfPresent(Bool.self, forKey: .esInterno) ?? false
        esRecurrente = try c.decodeIfPresent(Bool.self, forKey: .esRecurrente) ?? false
        revisada = try c.decodeIfPresent(Bool.self, forKey: .revisada) ?? false
        pareja = try c.decodeIfPresent(Pareja.self, forKey: .pareja)
    }
}

struct GrupoMesMov: Codable {
    let mes: String?
    let etiqueta: String?
    let conteo: Int?
    let totalGasto: Double?
    let totalGastoTexto: String?

    enum CodingKeys: String, CodingKey {
        case mes, etiqueta, conteo
        case totalGasto = "total_gasto"
        case totalGastoTexto = "total_gasto_texto"
    }
}

struct PaginacionMov: Codable {
    let total: Int?
    let porPagina: Int?
    let paginaActual: Int?
    let ultimaPagina: Int?

    enum CodingKeys: String, CodingKey {
        case total
        case porPagina = "por_pagina"
        case paginaActual = "pagina_actual"
        case ultimaPagina = "ultima_pagina"
    }

    var hayMas: Bool { (paginaActual ?? 1) < (ultimaPagina ?? 1) }
}

struct MovimientosRespuesta: Codable {
    let movimientos: [MovimientoFila]
    let conteo: Int?
    let totalGasto: Double?
    let totalGastoTexto: String?
    let gruposMes: [GrupoMesMov]
    let paginacion: PaginacionMov?

    enum CodingKeys: String, CodingKey {
        case movimientos, conteo
        case totalGasto = "total_gasto"
        case totalGastoTexto = "total_gasto_texto"
        case gruposMes = "grupos_mes"
        case paginacion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        movimientos = try c.decodeIfPresent([MovimientoFila].self, forKey: .movimientos) ?? []
        conteo = try c.decodeIfPresent(Int.self, forKey: .conteo)
        totalGasto = try c.decodeIfPresent(Double.self, forKey: .totalGasto)
        totalGastoTexto = try c.decodeIfPresent(String.self, forKey: .totalGastoTexto)
        gruposMes = try c.decodeIfPresent([GrupoMesMov].self, forKey: .gruposMes) ?? []
        paginacion = try c.decodeIfPresent(PaginacionMov.self, forKey: .paginacion)
    }
}

struct CuentaOpcion: Codable, Identifiable {
    let id: Int?
    let banco: String?
    let nombre: String?
    let mascara: String?
    let tipo: String?
}

struct OpcionesMovimientos: Codable {
    let cuentas: [CuentaOpcion]
    let categorias: [CategoriaMov]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cuentas = try c.decodeIfPresent([CuentaOpcion].self, forKey: .cuentas) ?? []
        categorias = try c.decodeIfPresent([CategoriaMov].self, forKey: .categorias) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case cuentas, categorias
    }
}

struct ParteMovimiento: Codable, Identifiable {
    // El servidor manda {id, monto, monto_texto, categoria, nota}; el
    // resto son nombres que la Android espera y llegan en null.
    var id: Int { _id ?? abs((montoTexto ?? "") .hashValue) }
    let _id: Int?
    let descripcion: String?
    let comercio: String?
    let nombre: String?
    let monto: Double?
    let montoTexto: String?
    let nota: String?
    let categoria: CategoriaMov?

    enum CodingKeys: String, CodingKey {
        case descripcion, comercio, nombre, monto, nota, categoria
        case _id = "id"
        case montoTexto = "monto_texto"
    }
}

struct MovimientoDetalle: Codable, Identifiable {
    let id: Int
    let comercio: String
    let logoUrl: String?
    let nombre: String?
    let fecha: String
    let fechaTexto: String
    let monto: Double
    let montoTexto: String
    let categoria: CategoriaMov?
    let cuenta: CuentaMov?
    let esManual: Bool
    let esInterno: Bool
    let pareja: Pareja?
    let categoriaOriginal: CategoriaMov?
    let categoriaCorregida: String?
    let nota: String?
    let pendiente: Bool
    let esDividido: Bool
    let partes: [ParteMovimiento]
    let nombreMostrar: String?
    let revisada: Bool
    let marcadaRecurrente: Bool
    let esRecurrente: Bool
    let etiquetas: [String]

    enum CodingKeys: String, CodingKey {
        case id, comercio, nombre, fecha, monto, categoria, cuenta, pareja, nota, pendiente, partes, etiquetas
        case logoUrl = "logo_url"
        case fechaTexto = "fecha_texto"
        case montoTexto = "monto_texto"
        case esManual = "es_manual"
        case esInterno = "es_interno"
        case categoriaOriginal = "categoria_original"
        case categoriaCorregida = "categoria_corregida"
        case esDividido = "es_dividido"
        case nombreMostrar = "nombre_mostrar"
        case marcadaRecurrente = "marcada_recurrente"
        case esRecurrente = "es_recurrente"
        case revisada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        comercio = try c.decode(String.self, forKey: .comercio)
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaTexto = try c.decodeIfPresent(String.self, forKey: .fechaTexto) ?? ""
        monto = try c.decode(Double.self, forKey: .monto)
        montoTexto = try c.decode(String.self, forKey: .montoTexto)
        categoria = try c.decodeIfPresent(CategoriaMov.self, forKey: .categoria)
        cuenta = try c.decodeIfPresent(CuentaMov.self, forKey: .cuenta)
        esManual = try c.decodeIfPresent(Bool.self, forKey: .esManual) ?? false
        esInterno = try c.decodeIfPresent(Bool.self, forKey: .esInterno) ?? false
        pareja = try c.decodeIfPresent(Pareja.self, forKey: .pareja)
        categoriaOriginal = try c.decodeIfPresent(CategoriaMov.self, forKey: .categoriaOriginal)
        categoriaCorregida = try c.decodeIfPresent(String.self, forKey: .categoriaCorregida)
        nota = try c.decodeIfPresent(String.self, forKey: .nota)
        pendiente = try c.decodeIfPresent(Bool.self, forKey: .pendiente) ?? false
        esDividido = try c.decodeIfPresent(Bool.self, forKey: .esDividido) ?? false
        partes = try c.decodeIfPresent([ParteMovimiento].self, forKey: .partes) ?? []
        nombreMostrar = try c.decodeIfPresent(String.self, forKey: .nombreMostrar)
        revisada = try c.decodeIfPresent(Bool.self, forKey: .revisada) ?? false
        marcadaRecurrente = try c.decodeIfPresent(Bool.self, forKey: .marcadaRecurrente) ?? false
        esRecurrente = try c.decodeIfPresent(Bool.self, forKey: .esRecurrente) ?? false
        etiquetas = try c.decodeIfPresent([String].self, forKey: .etiquetas) ?? []
    }
}

struct FichaMovimientoRespuesta: Codable {
    let movimiento: MovimientoDetalle
    let categorias: [CategoriaMov]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        movimiento = try c.decode(MovimientoDetalle.self, forKey: .movimiento)
        categorias = try c.decodeIfPresent([CategoriaMov].self, forKey: .categorias) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case movimiento, categorias
    }
}

struct GuardarMovimientoRespuesta: Codable {
    let movimiento: MovimientoDetalle?
    let mensaje: String?
}

struct HistorialMes: Codable {
    let mes: String?
    let etiqueta: String?
    let total: Double?
    let totalTexto: String?

    enum CodingKeys: String, CodingKey {
        case mes, etiqueta, total
        case totalTexto = "total_texto"
    }
}

struct HistorialPeriodo: Codable {
    let desdeTexto: String?
    let hastaTexto: String?
    let lapsoTexto: String?

    enum CodingKeys: String, CodingKey {
        case desdeTexto = "desde_texto"
        case hastaTexto = "hasta_texto"
        case lapsoTexto = "lapso_texto"
    }
}

struct LoteRespuesta: Codable {
    let actualizados: Int?
    let mensaje: String?
}

struct ManualRespuesta: Codable {
    let movimiento: MovimientoFila?
    let mensaje: String?
}

// MARK: - Fase 1: Gastos

struct GastoCategoria: Codable, Identifiable {
    var id: String { clave }
    let clave: String
    let nombre: String
    let monto: Double
    let montoTexto: String
    let porcentaje: Double
    let cambioPct: Double?
    let cambioDireccion: String?
    let color: String?
    let icono: String?

    enum CodingKeys: String, CodingKey {
        case clave, nombre, monto, porcentaje, color, icono
        case montoTexto = "monto_texto"
        case cambioPct = "cambio_pct"
        case cambioDireccion = "cambio_direccion"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decode(String.self, forKey: .clave)
        nombre = try c.decode(String.self, forKey: .nombre)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        porcentaje = try c.decodeIfPresent(Double.self, forKey: .porcentaje) ?? 0
        cambioPct = try c.decodeIfPresent(Double.self, forKey: .cambioPct)
        cambioDireccion = try c.decodeIfPresent(String.self, forKey: .cambioDireccion)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        icono = try c.decodeIfPresent(String.self, forKey: .icono)
    }
}

struct GastoPorMes: Codable {
    let mes: String?
    let etiqueta: String?
    let total: Double?
    let totalTexto: String?
    let ingreso: Double?
    let ingresoTexto: String?
    let esActual: Bool?

    enum CodingKeys: String, CodingKey {
        case mes, etiqueta, total, ingreso
        case totalTexto = "total_texto"
        case ingresoTexto = "ingreso_texto"
        case esActual = "es_actual"
    }
}

struct FilaBreve: Codable, Identifiable {
    let id: Int
    let comercio: String
    let logoUrl: String?
    let fecha: String
    let monto: Double
    let montoTexto: String
    let categoria: String?
    let motivo: String?

    enum CodingKeys: String, CodingKey {
        case id, comercio, fecha, monto, categoria, motivo
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        comercio = try c.decodeIfPresent(String.self, forKey: .comercio) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        categoria = try c.decodeIfPresent(String.self, forKey: .categoria)
        motivo = try c.decodeIfPresent(String.self, forKey: .motivo)
    }
}

struct FrecuenteGasto: Codable {
    let comercio: String
    let logoUrl: String?
    let veces: Int?
    let promedio: Double?
    let promedioTexto: String?
    let total: Double?
    let totalTexto: String?

    enum CodingKeys: String, CodingKey {
        case comercio, veces, promedio, total
        case logoUrl = "logo_url"
        case promedioTexto = "promedio_texto"
        case totalTexto = "total_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        comercio = try c.decodeIfPresent(String.self, forKey: .comercio) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        veces = try c.decodeIfPresent(Int.self, forKey: .veces)
        promedio = try c.decodeIfPresent(Double.self, forKey: .promedio)
        promedioTexto = try c.decodeIfPresent(String.self, forKey: .promedioTexto)
        total = try c.decodeIfPresent(Double.self, forKey: .total)
        totalTexto = try c.decodeIfPresent(String.self, forKey: .totalTexto)
    }
}

struct SeccionBreve: Codable {
    let cantidad: Int?
    let total: Double?
    let totalTexto: String?
    let filas: [FilaBreve]

    enum CodingKeys: String, CodingKey {
        case cantidad, total, filas
        case totalTexto = "total_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cantidad = try c.decodeIfPresent(Int.self, forKey: .cantidad) ?? 0
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        totalTexto = try c.decodeIfPresent(String.self, forKey: .totalTexto) ?? ""
        filas = try c.decodeIfPresent([FilaBreve].self, forKey: .filas) ?? []
    }
}

struct NoGasto: Codable {
    let filas: [FilaBreve]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        filas = try c.decodeIfPresent([FilaBreve].self, forKey: .filas) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case filas
    }
}

struct GastosRespuesta: Codable {
    let periodo: String
    let desde: String
    let hasta: String
    let total: Double
    let totalTexto: String
    let totalPrevio: Double?
    let totalPrevioTexto: String?
    let cambioTotalPct: Double?
    let categorias: [GastoCategoria]
    let porMes: [GastoPorMes]
    let ingreso: Double
    let ingresoTexto: String
    let neto: Double
    let netoTexto: String
    let netoFrase: String?
    let presupuesto: PresupuestoMes?
    let frecuentes: [FrecuenteGasto]
    let mayores: [FilaBreve]
    let intereses: SeccionBreve?
    let sinCategorizar: SeccionBreve?
    let noGasto: NoGasto?

    enum CodingKeys: String, CodingKey {
        case periodo, desde, hasta, total, categorias, ingreso, neto, presupuesto, frecuentes, mayores, intereses
        case totalTexto = "total_texto"
        case totalPrevio = "total_previo"
        case totalPrevioTexto = "total_previo_texto"
        case cambioTotalPct = "cambio_total_pct"
        case porMes = "por_mes"
        case ingresoTexto = "ingreso_texto"
        case netoTexto = "neto_texto"
        case netoFrase = "neto_frase"
        case sinCategorizar = "sin_categorizar"
        case noGasto = "no_gasto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        periodo = try c.decodeIfPresent(String.self, forKey: .periodo) ?? ""
        desde = try c.decodeIfPresent(String.self, forKey: .desde) ?? ""
        hasta = try c.decodeIfPresent(String.self, forKey: .hasta) ?? ""
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        totalTexto = try c.decodeIfPresent(String.self, forKey: .totalTexto) ?? ""
        totalPrevio = try c.decodeIfPresent(Double.self, forKey: .totalPrevio)
        totalPrevioTexto = try c.decodeIfPresent(String.self, forKey: .totalPrevioTexto)
        cambioTotalPct = try c.decodeIfPresent(Double.self, forKey: .cambioTotalPct)
        categorias = try c.decodeIfPresent([GastoCategoria].self, forKey: .categorias) ?? []
        porMes = try c.decodeIfPresent([GastoPorMes].self, forKey: .porMes) ?? []
        ingreso = try c.decodeIfPresent(Double.self, forKey: .ingreso) ?? 0
        ingresoTexto = try c.decodeIfPresent(String.self, forKey: .ingresoTexto) ?? ""
        neto = try c.decodeIfPresent(Double.self, forKey: .neto) ?? 0
        netoTexto = try c.decodeIfPresent(String.self, forKey: .netoTexto) ?? ""
        netoFrase = try c.decodeIfPresent(String.self, forKey: .netoFrase)
        presupuesto = try c.decodeIfPresent(PresupuestoMes.self, forKey: .presupuesto)
        frecuentes = try c.decodeIfPresent([FrecuenteGasto].self, forKey: .frecuentes) ?? []
        mayores = try c.decodeIfPresent([FilaBreve].self, forKey: .mayores) ?? []
        intereses = try c.decodeIfPresent(SeccionBreve.self, forKey: .intereses)
        sinCategorizar = try c.decodeIfPresent(SeccionBreve.self, forKey: .sinCategorizar)
        noGasto = try c.decodeIfPresent(NoGasto.self, forKey: .noGasto)
    }
}

struct CategoriaInfo: Codable {
    let clave: String?
    let nombre: String?
    let color: String?
    let icono: String?
}

struct BarraCategoria: Codable {
    let mes: String?
    let etiqueta: String?
    let total: Double?
    let totalTexto: String?
    let esElegido: Bool?

    enum CodingKeys: String, CodingKey {
        case mes, etiqueta, total
        case totalTexto = "total_texto"
        case esElegido = "es_elegido"
    }
}

struct PresupuestoCategoria: Codable {
    let limite: Double?
    let limiteTexto: String?
    let gastado: Double?
    let gastadoTexto: String?
    let diferencia: Double?
    let diferenciaTexto: String?
    let pasado: Bool?
    let porcentaje: Double?

    enum CodingKeys: String, CodingKey {
        case limite, gastado, diferencia, pasado, porcentaje
        case limiteTexto = "limite_texto"
        case gastadoTexto = "gastado_texto"
        case diferenciaTexto = "diferencia_texto"
    }
}

struct FilaCategoriaMov: Codable, Identifiable {
    let id: Int
    let comercio: String
    let logoUrl: String?
    let fecha: String
    let monto: Double
    let montoTexto: String
    let cuenta: CuentaMov?

    enum CodingKeys: String, CodingKey {
        case id, comercio, fecha, monto, cuenta
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        comercio = try c.decodeIfPresent(String.self, forKey: .comercio) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        cuenta = try c.decodeIfPresent(CuentaMov.self, forKey: .cuenta)
    }
}

struct TotalTransacciones: Codable {
    let cantidad: Int?
    let total: Double?
    let totalTexto: String?

    enum CodingKeys: String, CodingKey {
        case cantidad, total
        case totalTexto = "total_texto"
    }
}

struct CategoriaDetalleRespuesta: Codable {
    let categoria: CategoriaInfo?
    let mes: String
    let mesEtiqueta: String
    let barras: [BarraCategoria]
    let presupuesto: PresupuestoCategoria?
    let movimientos: [FilaCategoriaMov]
    let totalTransacciones: TotalTransacciones?

    enum CodingKeys: String, CodingKey {
        case categoria, mes, barras, presupuesto, movimientos
        case mesEtiqueta = "mes_etiqueta"
        case totalTransacciones = "total_transacciones"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        categoria = try c.decodeIfPresent(CategoriaInfo.self, forKey: .categoria)
        mes = try c.decodeIfPresent(String.self, forKey: .mes) ?? ""
        mesEtiqueta = try c.decodeIfPresent(String.self, forKey: .mesEtiqueta) ?? ""
        barras = try c.decodeIfPresent([BarraCategoria].self, forKey: .barras) ?? []
        presupuesto = try c.decodeIfPresent(PresupuestoCategoria.self, forKey: .presupuesto)
        movimientos = try c.decodeIfPresent([FilaCategoriaMov].self, forKey: .movimientos) ?? []
        totalTransacciones = try c.decodeIfPresent(TotalTransacciones.self, forKey: .totalTransacciones)
    }
}

// MARK: - Fase 1: Deudas

struct DeudaItem: Codable, Identifiable {
    let id: Int
    let nombre: String
    let banco: String?
    let mascara: String?
    let saldo: Double
    let saldoTexto: String
    let apr: Double?
    let aprTexto: String?
    let pagoMinimo: Double?
    let pagoMinimoTexto: String?
    let diaVencimiento: Int?
    let tipo: String?
    let liquidada: Bool

    enum CodingKeys: String, CodingKey {
        case id, nombre, banco, mascara, saldo, apr, tipo
        case saldoTexto = "saldo_texto"
        case aprTexto = "apr_texto"
        case pagoMinimo = "pago_minimo"
        case pagoMinimoTexto = "pago_minimo_texto"
        case diaVencimiento = "dia_vencimiento"
        case liquidada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nombre = try c.decode(String.self, forKey: .nombre)
        banco = try c.decodeIfPresent(String.self, forKey: .banco)
        mascara = try c.decodeIfPresent(String.self, forKey: .mascara)
        saldo = try c.decodeIfPresent(Double.self, forKey: .saldo) ?? 0
        saldoTexto = try c.decodeIfPresent(String.self, forKey: .saldoTexto) ?? ""
        apr = try c.decodeIfPresent(Double.self, forKey: .apr)
        aprTexto = try c.decodeIfPresent(String.self, forKey: .aprTexto)
        pagoMinimo = try c.decodeIfPresent(Double.self, forKey: .pagoMinimo)
        pagoMinimoTexto = try c.decodeIfPresent(String.self, forKey: .pagoMinimoTexto)
        diaVencimiento = try c.decodeIfPresent(Int.self, forKey: .diaVencimiento)
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo)
        liquidada = try c.decodeIfPresent(Bool.self, forKey: .liquidada) ?? false
    }
}

struct PlanDeudas: Codable {
    let estrategia: String
    let estrategiaTexto: String
    let extra: Double
    let extraTexto: String

    enum CodingKeys: String, CodingKey {
        case estrategia, extra
        case estrategiaTexto = "estrategia_texto"
        case extraTexto = "extra_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estrategia = try c.decodeIfPresent(String.self, forKey: .estrategia) ?? ""
        estrategiaTexto = try c.decodeIfPresent(String.self, forKey: .estrategiaTexto) ?? ""
        extra = try c.decodeIfPresent(Double.self, forKey: .extra) ?? 0
        extraTexto = try c.decodeIfPresent(String.self, forKey: .extraTexto) ?? ""
    }
}

struct DeudasRespuesta: Codable {
    let deudas: [DeudaItem]
    let plan: PlanDeudas?
    let fechaLibertad: String?
    let fechaLibertadTexto: String?
    let meses: Int?
    let interesTotal: Double?
    let interesTotalTexto: String?
    let presupuestoMensual: Double?
    let presupuestoMensualTexto: String?
    let serie: [SeriePunto]
    let serieMinimos: [SeriePunto]

    enum CodingKeys: String, CodingKey {
        case deudas, plan, meses, serie
        case fechaLibertad = "fecha_libertad"
        case fechaLibertadTexto = "fecha_libertad_texto"
        case interesTotal = "interes_total"
        case interesTotalTexto = "interes_total_texto"
        case presupuestoMensual = "presupuesto_mensual"
        case presupuestoMensualTexto = "presupuesto_mensual_texto"
        case serieMinimos = "serie_minimos"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deudas = try c.decodeIfPresent([DeudaItem].self, forKey: .deudas) ?? []
        plan = try c.decodeIfPresent(PlanDeudas.self, forKey: .plan)
        fechaLibertad = try c.decodeIfPresent(String.self, forKey: .fechaLibertad)
        fechaLibertadTexto = try c.decodeIfPresent(String.self, forKey: .fechaLibertadTexto)
        meses = try c.decodeIfPresent(Int.self, forKey: .meses)
        interesTotal = try c.decodeIfPresent(Double.self, forKey: .interesTotal)
        interesTotalTexto = try c.decodeIfPresent(String.self, forKey: .interesTotalTexto)
        presupuestoMensual = try c.decodeIfPresent(Double.self, forKey: .presupuestoMensual)
        presupuestoMensualTexto = try c.decodeIfPresent(String.self, forKey: .presupuestoMensualTexto)
        serie = try c.decodeIfPresent([SeriePunto].self, forKey: .serie) ?? []
        serieMinimos = try c.decodeIfPresent([SeriePunto].self, forKey: .serieMinimos) ?? []
    }
}

struct ComparacionSimulacion: Codable {
    let estrategiaActual: String?
    let extraActual: Double?
    let mesesActual: Int?
    let fechaLibertadActual: String?
    let fechaLibertadActualTexto: String?
    let mesesDiferencia: Int?
    let diasAdelantados: Int?
    let interesAhorrado: Double?
    let interesAhorradoTexto: String?

    enum CodingKeys: String, CodingKey {
        case mesesDiferencia = "meses_diferencia"
        case diasAdelantados = "dias_adelantados"
        case interesAhorrado = "interes_ahorrado"
        case interesAhorradoTexto = "interes_ahorrado_texto"
        case estrategiaActual = "estrategia_actual"
        case extraActual = "extra_actual"
        case mesesActual = "meses_actual"
        case fechaLibertadActual = "fecha_libertad_actual"
        case fechaLibertadActualTexto = "fecha_libertad_actual_texto"
    }
}

struct SimulacionDeudas: Codable {
    let estrategia: String?
    let extra: Double?
    let meses: Int?
    let fechaLibertad: String?
    let fechaLibertadTexto: String?
    let interesTotal: Double?
    let interesTotalTexto: String?
    let presupuestoMensual: Double?
    let presupuestoMensualTexto: String?
    let serie: [SeriePunto]
    let sinLiquidar: [ValorFlexible]
    let comparacion: ComparacionSimulacion?

    enum CodingKeys: String, CodingKey {
        case estrategia, extra, meses, comparacion
        case fechaLibertad = "fecha_libertad"
        case fechaLibertadTexto = "fecha_libertad_texto"
        case interesTotal = "interes_total"
        case interesTotalTexto = "interes_total_texto"
        case presupuestoMensual = "presupuesto_mensual"
        case presupuestoMensualTexto = "presupuesto_mensual_texto"
        case serie
        case sinLiquidar = "sin_liquidar"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estrategia = try c.decodeIfPresent(String.self, forKey: .estrategia)
        extra = try c.decodeIfPresent(Double.self, forKey: .extra)
        meses = try c.decodeIfPresent(Int.self, forKey: .meses)
        fechaLibertad = try c.decodeIfPresent(String.self, forKey: .fechaLibertad)
        fechaLibertadTexto = try c.decodeIfPresent(String.self, forKey: .fechaLibertadTexto)
        interesTotal = try c.decodeIfPresent(Double.self, forKey: .interesTotal)
        interesTotalTexto = try c.decodeIfPresent(String.self, forKey: .interesTotalTexto)
        presupuestoMensual = try c.decodeIfPresent(Double.self, forKey: .presupuestoMensual)
        presupuestoMensualTexto = try c.decodeIfPresent(String.self, forKey: .presupuestoMensualTexto)
        serie = try c.decodeIfPresent([SeriePunto].self, forKey: .serie) ?? []
        sinLiquidar = try c.decodeIfPresent([ValorFlexible].self, forKey: .sinLiquidar) ?? []
        comparacion = try c.decodeIfPresent(ComparacionSimulacion.self, forKey: .comparacion)
    }
}

struct GuardarDatosDeudaRespuesta: Codable {
    let ok: Bool?
    let deuda: DeudaItem?
    let mensaje: String?
}

// MARK: - Fase 1: Recurrentes y calendario

struct RecurrenteItem: Codable {
    let id: Int?
    let comercio: String
    let logoUrl: String?
    let tipo: String?
    let monto: Double
    let montoTexto: String
    let costoMensual: Double?
    let costoMensualTexto: String?
    let costoAnual: Double?
    let costoAnualTexto: String?
    let proximaFecha: String?
    let dias: Int?
    let frecuencia: String?
    let frecuenciaTexto: String?
    let cancelada: Bool
    let estadoCancelacion: String?
    let cuenta: String?

    enum CodingKeys: String, CodingKey {
        case id, comercio, tipo, monto, dias, frecuencia, cuenta
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
        case costoMensual = "costo_mensual"
        case costoMensualTexto = "costo_mensual_texto"
        case costoAnual = "costo_anual"
        case costoAnualTexto = "costo_anual_texto"
        case proximaFecha = "proxima_fecha"
        case frecuenciaTexto = "frecuencia_texto"
        case estadoCancelacion = "estado_cancelacion"
        case cancelada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        comercio = try c.decode(String.self, forKey: .comercio)
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        costoMensual = try c.decodeIfPresent(Double.self, forKey: .costoMensual)
        costoMensualTexto = try c.decodeIfPresent(String.self, forKey: .costoMensualTexto)
        costoAnual = try c.decodeIfPresent(Double.self, forKey: .costoAnual)
        costoAnualTexto = try c.decodeIfPresent(String.self, forKey: .costoAnualTexto)
        proximaFecha = try c.decodeIfPresent(String.self, forKey: .proximaFecha)
        dias = try c.decodeIfPresent(Int.self, forKey: .dias)
        frecuencia = try c.decodeIfPresent(String.self, forKey: .frecuencia)
        frecuenciaTexto = try c.decodeIfPresent(String.self, forKey: .frecuenciaTexto)
        cancelada = try c.decodeIfPresent(Bool.self, forKey: .cancelada) ?? false
        estadoCancelacion = try c.decodeIfPresent(String.self, forKey: .estadoCancelacion)
        cuenta = try c.decodeIfPresent(String.self, forKey: .cuenta)
    }
}

struct GrupoRecurrente: Codable {
    let clave: String
    let etiqueta: String
    let cantidad: Int?
    let totalAnual: Double?
    let totalAnualTexto: String?
    let totalMensual: Double?
    let totalMensualTexto: String?

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, cantidad
        case totalAnual = "total_anual"
        case totalAnualTexto = "total_anual_texto"
        case totalMensual = "total_mensual"
        case totalMensualTexto = "total_mensual_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        cantidad = try c.decodeIfPresent(Int.self, forKey: .cantidad)
        totalAnual = try c.decodeIfPresent(Double.self, forKey: .totalAnual)
        totalAnualTexto = try c.decodeIfPresent(String.self, forKey: .totalAnualTexto)
        totalMensual = try c.decodeIfPresent(Double.self, forKey: .totalMensual)
        totalMensualTexto = try c.decodeIfPresent(String.self, forKey: .totalMensualTexto)
    }
}

struct CobroAntesPago: Codable, Identifiable {
    var id: String { comercio + fecha }
    let comercio: String
    let logoUrl: String?
    let monto: Double
    let montoTexto: String
    let fecha: String
    let dias: Int

    enum CodingKeys: String, CodingKey {
        case comercio, monto, fecha, dias
        case logoUrl = "logo_url"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        comercio = try c.decodeIfPresent(String.self, forKey: .comercio) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        dias = try c.decodeIfPresent(Int.self, forKey: .dias) ?? 0
    }
}

struct AntesDelPago: Codable {
    let efectivo: Double
    let efectivoTexto: String
    let proximoPago: String
    let proximoPagoTexto: String
    let totalCobros: Double
    let totalCobrosTexto: String
    let seguro: Double
    let seguroTexto: String
    let cobros: [CobroAntesPago]

    enum CodingKeys: String, CodingKey {
        case efectivo, seguro, cobros
        case efectivoTexto = "efectivo_texto"
        case proximoPago = "proximo_pago"
        case proximoPagoTexto = "proximo_pago_texto"
        case totalCobros = "total_cobros"
        case totalCobrosTexto = "total_cobros_texto"
        case seguroTexto = "seguro_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        efectivo = try c.decodeIfPresent(Double.self, forKey: .efectivo) ?? 0
        efectivoTexto = try c.decodeIfPresent(String.self, forKey: .efectivoTexto) ?? ""
        proximoPago = try c.decodeIfPresent(String.self, forKey: .proximoPago) ?? ""
        proximoPagoTexto = try c.decodeIfPresent(String.self, forKey: .proximoPagoTexto) ?? ""
        totalCobros = try c.decodeIfPresent(Double.self, forKey: .totalCobros) ?? 0
        totalCobrosTexto = try c.decodeIfPresent(String.self, forKey: .totalCobrosTexto) ?? ""
        seguro = try c.decodeIfPresent(Double.self, forKey: .seguro) ?? 0
        seguroTexto = try c.decodeIfPresent(String.self, forKey: .seguroTexto) ?? ""
        cobros = try c.decodeIfPresent([CobroAntesPago].self, forKey: .cobros) ?? []
    }
}

struct RecientesRecurrentes: Codable {
    let cantidad: Int?
    let total: Double?
    let totalTexto: String?
    let filas: [FilaBreve]

    enum CodingKeys: String, CodingKey {
        case cantidad, total, filas
        case totalTexto = "total_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cantidad = try c.decodeIfPresent(Int.self, forKey: .cantidad) ?? 0
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        totalTexto = try c.decodeIfPresent(String.self, forKey: .totalTexto) ?? ""
        filas = try c.decodeIfPresent([FilaBreve].self, forKey: .filas) ?? []
    }
}

struct RecurrentesRespuesta: Codable {
    let cargos: [RecurrenteItem]
    let orden: String
    let grupos: [GrupoRecurrente]
    let antesDelPago: AntesDelPago?
    let recientes: RecientesRecurrentes?

    enum CodingKeys: String, CodingKey {
        case cargos, orden, grupos, recientes
        case antesDelPago = "antes_del_pago"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cargos = try c.decodeIfPresent([RecurrenteItem].self, forKey: .cargos) ?? []
        orden = try c.decodeIfPresent(String.self, forKey: .orden) ?? "monto"
        grupos = try c.decodeIfPresent([GrupoRecurrente].self, forKey: .grupos) ?? []
        antesDelPago = try c.decodeIfPresent(AntesDelPago.self, forKey: .antesDelPago)
        recientes = try c.decodeIfPresent(RecientesRecurrentes.self, forKey: .recientes)
    }
}

struct CalendarioEvento: Codable {
    let tipo: String
    let titulo: String
    let logoUrl: String?
    let monto: Double?
    let montoTexto: String?
    let pagado: Bool

    enum CodingKeys: String, CodingKey {
        case tipo, titulo, pagado
        case logoUrl = "logo_url"
        case monto = "monto"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? ""
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? ""
        logoUrl = try c.decodeIfPresent(String.self, forKey: .logoUrl)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto)
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto)
        pagado = try c.decodeIfPresent(Bool.self, forKey: .pagado) ?? false
    }
}

struct CalendarioDia: Codable, Identifiable {
    var id: String { fecha }
    let fecha: String
    let fechaTexto: String
    let esHoy: Bool
    let saldoProyectado: Double?
    let saldoProyectadoTexto: String?
    let riesgo: Bool
    let esPago: Bool
    let eventos: [CalendarioEvento]

    enum CodingKeys: String, CodingKey {
        case fecha, riesgo, eventos
        case fechaTexto = "fecha_texto"
        case esHoy = "es_hoy"
        case saldoProyectado = "saldo_proyectado"
        case saldoProyectadoTexto = "saldo_proyectado_texto"
        case esPago = "es_pago"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaTexto = try c.decodeIfPresent(String.self, forKey: .fechaTexto) ?? ""
        esHoy = try c.decodeIfPresent(Bool.self, forKey: .esHoy) ?? false
        saldoProyectado = try c.decodeIfPresent(Double.self, forKey: .saldoProyectado)
        saldoProyectadoTexto = try c.decodeIfPresent(String.self, forKey: .saldoProyectadoTexto)
        riesgo = try c.decodeIfPresent(Bool.self, forKey: .riesgo) ?? false
        esPago = try c.decodeIfPresent(Bool.self, forKey: .esPago) ?? false
        eventos = try c.decodeIfPresent([CalendarioEvento].self, forKey: .eventos) ?? []
    }
}

struct CalendarioResumen: Codable {
    let cobrosTotal: Double?
    let cobrosTotalTexto: String?
    let vencimientosTotal: Double?
    let vencimientosTotalTexto: String?
    let ingresosTotal: Double?
    let ingresosTotalTexto: String?
    let gastosTotal: Double?
    let gastosTotalTexto: String?

    enum CodingKeys: String, CodingKey {
        case cobrosTotal = "cobros_total"
        case cobrosTotalTexto = "cobros_total_texto"
        case vencimientosTotal = "vencimientos_total"
        case vencimientosTotalTexto = "vencimientos_total_texto"
        case ingresosTotal = "ingresos_total"
        case ingresosTotalTexto = "ingresos_total_texto"
        case gastosTotal = "gastos_total"
        case gastosTotalTexto = "gastos_total_texto"
    }
}

struct CalendarioRespuesta: Codable {
    let mes: String
    let mesTexto: String
    let dias: [CalendarioDia]
    let resumen: CalendarioResumen?
    let alertaFecha: String?
    let alertaFechaTexto: String?

    enum CodingKeys: String, CodingKey {
        case mes, dias, resumen
        case mesTexto = "mes_texto"
        case alertaFecha = "alerta_fecha"
        case alertaFechaTexto = "alerta_fecha_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mes = try c.decodeIfPresent(String.self, forKey: .mes) ?? ""
        mesTexto = try c.decodeIfPresent(String.self, forKey: .mesTexto) ?? ""
        dias = try c.decodeIfPresent([CalendarioDia].self, forKey: .dias) ?? []
        resumen = try c.decodeIfPresent(CalendarioResumen.self, forKey: .resumen)
        alertaFecha = try c.decodeIfPresent(String.self, forKey: .alertaFecha)
        alertaFechaTexto = try c.decodeIfPresent(String.self, forKey: .alertaFechaTexto)
    }
}

// MARK: - Fase 1: Mas, membresia y Ajustes

struct MembresiaDto: Codable {
    let pruebaEstado: String?
    let enPrueba: Bool
    let finPrueba: String?
    let finPruebaTexto: String?
    let diasRestantesPrueba: Int?
    let enPausa: Bool
    let motivoPausa: String?
    let suscripcionVigente: Bool
    let planPagadoHasta: String?
    let planPagadoHastaTexto: String?
    let planNoRenueva: Bool

    enum CodingKeys: String, CodingKey {
        case enPrueba = "en_prueba"
        case enPausa = "en_pausa"
        case suscripcionVigente = "suscripcion_vigente"
        case planNoRenueva = "plan_no_renueva"
        case pruebaEstado = "prueba_estado"
        case finPrueba = "fin_prueba"
        case finPruebaTexto = "fin_prueba_texto"
        case diasRestantesPrueba = "dias_restantes_prueba"
        case motivoPausa = "motivo_pausa"
        case planPagadoHasta = "plan_pagado_hasta"
        case planPagadoHastaTexto = "plan_pagado_hasta_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pruebaEstado = try c.decodeIfPresent(String.self, forKey: .pruebaEstado)
        enPrueba = try c.decodeIfPresent(Bool.self, forKey: .enPrueba) ?? false
        finPrueba = try c.decodeIfPresent(String.self, forKey: .finPrueba)
        finPruebaTexto = try c.decodeIfPresent(String.self, forKey: .finPruebaTexto)
        diasRestantesPrueba = try c.decodeIfPresent(Int.self, forKey: .diasRestantesPrueba)
        enPausa = try c.decodeIfPresent(Bool.self, forKey: .enPausa) ?? false
        motivoPausa = try c.decodeIfPresent(String.self, forKey: .motivoPausa)
        suscripcionVigente = try c.decodeIfPresent(Bool.self, forKey: .suscripcionVigente) ?? false
        planPagadoHasta = try c.decodeIfPresent(String.self, forKey: .planPagadoHasta)
        planPagadoHastaTexto = try c.decodeIfPresent(String.self, forKey: .planPagadoHastaTexto)
        planNoRenueva = try c.decodeIfPresent(Bool.self, forKey: .planNoRenueva) ?? false
    }
}

struct MasRespuesta: Codable {
    let membresia: MembresiaDto?
}

struct MembresiaGestion: Codable {
    let estado: String
    let titulo: String
    let detalle: String
    let precioMensualTexto: String?
    let precioAnualTexto: String?
    let puedePagar: Bool
    let puedeGestionar: Bool
    let puedeCancelar: Bool
    let noRenueva: Bool
    let lifetime: Bool

    enum CodingKeys: String, CodingKey {
        case estado, titulo, detalle
        case precioMensualTexto = "precio_mensual_texto"
        case precioAnualTexto = "precio_anual_texto"
        case puedePagar = "puede_pagar"
        case puedeGestionar = "puede_gestionar"
        case puedeCancelar = "puede_cancelar"
        case noRenueva = "no_renueva"
        case lifetime
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estado = try c.decodeIfPresent(String.self, forKey: .estado) ?? ""
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? ""
        detalle = try c.decodeIfPresent(String.self, forKey: .detalle) ?? ""
        precioMensualTexto = try c.decodeIfPresent(String.self, forKey: .precioMensualTexto)
        precioAnualTexto = try c.decodeIfPresent(String.self, forKey: .precioAnualTexto)
        puedePagar = try c.decodeIfPresent(Bool.self, forKey: .puedePagar) ?? false
        puedeGestionar = try c.decodeIfPresent(Bool.self, forKey: .puedeGestionar) ?? false
        puedeCancelar = try c.decodeIfPresent(Bool.self, forKey: .puedeCancelar) ?? false
        noRenueva = try c.decodeIfPresent(Bool.self, forKey: .noRenueva) ?? false
        lifetime = try c.decodeIfPresent(Bool.self, forKey: .lifetime) ?? false
    }
}

struct AjustesPerfil: Codable {
    let nombre: String
    let correo: String
    let fotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case nombre, correo
        case fotoUrl = "foto_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        correo = try c.decodeIfPresent(String.self, forKey: .correo) ?? ""
        fotoUrl = try c.decodeIfPresent(String.self, forKey: .fotoUrl)
    }
}

struct AjustesCiclo: Decodable {
    let frecuencia: String?
    let frecuencias: [String]
    let proximoPago: String?
    let diaA: Int?
    let diaB: Int?
    let configurado: Bool
    /// Campo libre `sugerencia.frecuencia` del servidor (solo se lee eso).
    let sugerenciaFrecuencia: String?

    enum CodingKeys: String, CodingKey {
        case frecuencia, frecuencias, sugerencia
        case proximoPago = "proximo_pago"
        case diaA = "dia_a"
        case diaB = "dia_b"
        case configurado
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        frecuencia = try c.decodeIfPresent(String.self, forKey: .frecuencia)
        frecuencias = try c.decodeIfPresent([String].self, forKey: .frecuencias) ?? []
        proximoPago = try c.decodeIfPresent(String.self, forKey: .proximoPago)
        diaA = try c.decodeIfPresent(Int.self, forKey: .diaA)
        diaB = try c.decodeIfPresent(Int.self, forKey: .diaB)
        configurado = try c.decodeIfPresent(Bool.self, forKey: .configurado) ?? false
        if let objeto = try? c.decodeIfPresent(JSONValue.self, forKey: .sugerencia),
           case .objeto(let dict) = objeto, case .texto(let frec)? = dict["frecuencia"] {
            sugerenciaFrecuencia = frec
        } else {
            sugerenciaFrecuencia = nil
        }
    }
}

/// Un valor JSON generico, para campos libres del servidor que la app
/// solo lee a medias (como `sugerencia` del ciclo de pago).
indirect enum JSONValue: Codable {
    case texto(String)
    case numero(Double)
    case booleano(Bool)
    case objeto([String: JSONValue])
    case lista([JSONValue])
    case nulo

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .nulo; return }
        if let b = try? c.decode(Bool.self) { self = .booleano(b); return }
        if let n = try? c.decode(Double.self) { self = .numero(n); return }
        if let t = try? c.decode(String.self) { self = .texto(t); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .objeto(o); return }
        if let l = try? c.decode([JSONValue].self) { self = .lista(l); return }
        self = .nulo
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .texto(let t): try c.encode(t)
        case .numero(let n): try c.encode(n)
        case .booleano(let b): try c.encode(b)
        case .objeto(let o): try c.encode(o)
        case .lista(let l): try c.encode(l)
        case .nulo: try c.encodeNil()
        }
    }
}

struct NotificacionesPrefs: Codable {
    var avisoPresupuesto: Bool
    var avisoVencimientoDeuda: Bool
    var avisoSobregiro: Bool
    var resumenSemanal: Bool
    var pushDinero: Bool
    var pushRecordatorios: Bool

    enum CodingKeys: String, CodingKey {
        case avisoPresupuesto = "aviso_presupuesto"
        case avisoVencimientoDeuda = "aviso_vencimiento_deuda"
        case avisoSobregiro = "aviso_sobregiro"
        case resumenSemanal = "resumen_semanal"
        case pushDinero = "push_dinero"
        case pushRecordatorios = "push_recordatorios"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avisoPresupuesto = try c.decodeIfPresent(Bool.self, forKey: .avisoPresupuesto) ?? true
        avisoVencimientoDeuda = try c.decodeIfPresent(Bool.self, forKey: .avisoVencimientoDeuda) ?? true
        avisoSobregiro = try c.decodeIfPresent(Bool.self, forKey: .avisoSobregiro) ?? true
        resumenSemanal = try c.decodeIfPresent(Bool.self, forKey: .resumenSemanal) ?? false
        pushDinero = try c.decodeIfPresent(Bool.self, forKey: .pushDinero) ?? true
        pushRecordatorios = try c.decodeIfPresent(Bool.self, forKey: .pushRecordatorios) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(avisoPresupuesto, forKey: .avisoPresupuesto)
        try c.encode(avisoVencimientoDeuda, forKey: .avisoVencimientoDeuda)
        try c.encode(avisoSobregiro, forKey: .avisoSobregiro)
        try c.encode(resumenSemanal, forKey: .resumenSemanal)
        try c.encode(pushDinero, forKey: .pushDinero)
        try c.encode(pushRecordatorios, forKey: .pushRecordatorios)
    }
}

struct ColorCategoria: Codable, Identifiable {
    var id: String { clave }
    let clave: String
    let nombre: String
    let color: String
    let personalizado: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        personalizado = try c.decodeIfPresent(Bool.self, forKey: .personalizado) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case clave, nombre, color, personalizado
    }
}

struct CategoriaPersonalizada: Codable, Identifiable {
    let id: Int
    let clave: String
    let nombre: String
    let color: String
    let icono: String
    let tipo: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#6B7280"
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? "etiqueta"
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? "gasto"
    }

    init(id: Int, clave: String, nombre: String, color: String, icono: String, tipo: String) {
        self.id = id
        self.clave = clave
        self.nombre = nombre
        self.color = color
        self.icono = icono
        self.tipo = tipo
    }

    enum CodingKeys: String, CodingKey {
        case clave, nombre, color, icono, tipo
        case id
    }
}

struct IconoElegible: Codable {
    let clave: String
    let nombre: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case clave, nombre
    }
}

struct ReglaMovimiento: Codable, Identifiable {
    let id: Int
    let texto: String
    let categoria: String?
    let categoriaNombre: String?
    let marcarInterna: Bool
    let activa: Bool

    enum CodingKeys: String, CodingKey {
        case id, texto, categoria
        case categoriaNombre = "categoria_nombre"
        case marcarInterna = "marcar_interna"
        case activa
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        texto = try c.decodeIfPresent(String.self, forKey: .texto) ?? ""
        categoria = try c.decodeIfPresent(String.self, forKey: .categoria)
        categoriaNombre = try c.decodeIfPresent(String.self, forKey: .categoriaNombre)
        marcarInterna = try c.decodeIfPresent(Bool.self, forKey: .marcarInterna) ?? false
        activa = try c.decodeIfPresent(Bool.self, forKey: .activa) ?? false
    }
}

struct SeguridadAjustes: Codable {
    let activa: Bool
    let metodo: String?
    let pendiente: Bool

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activa = try c.decodeIfPresent(Bool.self, forKey: .activa) ?? false
        metodo = try c.decodeIfPresent(String.self, forKey: .metodo)
        pendiente = try c.decodeIfPresent(Bool.self, forKey: .pendiente) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case activa, metodo, pendiente
    }
}

struct LlaveAsistente: Codable, Identifiable {
    let id: Int
    let nombre: String
    let creada: String?
    let ultimoUso: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, creada
        case ultimoUso = "ultimo_uso"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        creada = try c.decodeIfPresent(String.self, forKey: .creada)
        ultimoUso = try c.decodeIfPresent(String.self, forKey: .ultimoUso)
    }
}

struct AsistenteAjustes: Codable {
    let llaves: [LlaveAsistente]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llaves = try c.decodeIfPresent([LlaveAsistente].self, forKey: .llaves) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case llaves
    }
}

struct AjustesRespuesta: Decodable {
    let perfil: AjustesPerfil?
    let ciclo: AjustesCiclo?
    let notificaciones: NotificacionesPrefs?
    let colores: [ColorCategoria]
    let personalizadas: [CategoriaPersonalizada]
    let iconos: [IconoElegible]
    let reglas: [ReglaMovimiento]
    let seguridad: SeguridadAjustes?
    let asistente: AsistenteAjustes?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        perfil = try c.decodeIfPresent(AjustesPerfil.self, forKey: .perfil)
        ciclo = try c.decodeIfPresent(AjustesCiclo.self, forKey: .ciclo)
        notificaciones = try c.decodeIfPresent(NotificacionesPrefs.self, forKey: .notificaciones)
        colores = try c.decodeIfPresent([ColorCategoria].self, forKey: .colores) ?? []
        personalizadas = try c.decodeIfPresent([CategoriaPersonalizada].self, forKey: .personalizadas) ?? []
        iconos = try c.decodeIfPresent([IconoElegible].self, forKey: .iconos) ?? []
        reglas = try c.decodeIfPresent([ReglaMovimiento].self, forKey: .reglas) ?? []
        seguridad = try c.decodeIfPresent(SeguridadAjustes.self, forKey: .seguridad)
        asistente = try c.decodeIfPresent(AsistenteAjustes.self, forKey: .asistente)
    }

    enum CodingKeys: String, CodingKey {
        case perfil, ciclo, notificaciones, colores, personalizadas, iconos, reglas, seguridad, asistente
    }
}

struct ConexionCuenta: Codable {
    let id: Int
    let institucion: String?
    let estado: String?
    let estadoTexto: String?
    let necesitaAtencion: Bool
    let ultimaSyncTexto: String?
    let desactualizada: Bool

    enum CodingKeys: String, CodingKey {
        case id, institucion, estado
        case estadoTexto = "estado_texto"
        case necesitaAtencion = "necesita_atencion"
        case ultimaSyncTexto = "ultima_sync_texto"
        case desactualizada
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        institucion = try c.decodeIfPresent(String.self, forKey: .institucion)
        estado = try c.decodeIfPresent(String.self, forKey: .estado)
        estadoTexto = try c.decodeIfPresent(String.self, forKey: .estadoTexto)
        necesitaAtencion = try c.decodeIfPresent(Bool.self, forKey: .necesitaAtencion) ?? false
        ultimaSyncTexto = try c.decodeIfPresent(String.self, forKey: .ultimaSyncTexto)
        desactualizada = try c.decodeIfPresent(Bool.self, forKey: .desactualizada) ?? false
    }
}

struct CuentaEstado: Codable, Identifiable {
    let id: Int
    let banco: String
    let nombre: String
    let mascara: String?
    let saldo: Double
    let saldoTexto: String
    let tipo: String
    let subtipo: String?
    let conexion: ConexionCuenta?

    enum CodingKeys: String, CodingKey {
        case id, banco, nombre, mascara, saldo, tipo, subtipo, conexion
        case saldoTexto = "saldo_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        banco = try c.decodeIfPresent(String.self, forKey: .banco) ?? ""
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        mascara = try c.decodeIfPresent(String.self, forKey: .mascara)
        saldo = try c.decodeIfPresent(Double.self, forKey: .saldo) ?? 0
        saldoTexto = try c.decodeIfPresent(String.self, forKey: .saldoTexto) ?? ""
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? ""
        subtipo = try c.decodeIfPresent(String.self, forKey: .subtipo)
        conexion = try c.decodeIfPresent(ConexionCuenta.self, forKey: .conexion)
    }
}

struct CuentasEstadoRespuesta: Codable {
    let cuentas: [CuentaEstado]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cuentas = try c.decodeIfPresent([CuentaEstado].self, forKey: .cuentas) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case cuentas
    }
}

struct FotoRespuesta: Codable {
    let fotoUrl: String?
    let mensaje: String?

    enum CodingKeys: String, CodingKey {
        case fotoUrl = "foto_url"
        case mensaje
    }
}

struct SeguridadIniciar: Codable {
    let mensaje: String?
    let esperaSegundos: Int?
    let llave: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case mensaje, llave, url
        case esperaSegundos = "espera_segundos"
    }
}

struct SeguridadConfirmada: Codable {
    let codigosRecuperacion: [String]
    let mensaje: String?

    enum CodingKeys: String, CodingKey {
        case mensaje
        case codigosRecuperacion = "codigos_recuperacion"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        codigosRecuperacion = try c.decodeIfPresent([String].self, forKey: .codigosRecuperacion) ?? []
        mensaje = try c.decodeIfPresent(String.self, forKey: .mensaje)
    }
}

struct LlaveCreada: Codable {
    let llave: String
    let mensaje: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llave = try c.decodeIfPresent(String.self, forKey: .llave) ?? ""
        mensaje = try c.decodeIfPresent(String.self, forKey: .mensaje)
    }

    enum CodingKeys: String, CodingKey {
        case llave, mensaje
    }
}

struct ReglaCreada: Codable {
    let id: Int?
    let mensaje: String?
}

struct AlternarRegla: Codable {
    let activa: Bool?
    let mensaje: String?
}

struct CategoriaCreada: Codable {
    let mensaje: String?
    let categoria: CategoriaPersonalizada?
}

struct UrlRespuesta: Codable {
    let url: String?
}

struct NotificacionCentro: Codable, Identifiable {
    let id: Int
    let tipo: String
    let titulo: String
    let cuerpo: String
    let fecha: String
    let fechaIso: String?
    let leida: Bool

    enum CodingKeys: String, CodingKey {
        case id, tipo, titulo, cuerpo, fecha, leida
        case fechaIso = "fecha_iso"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? ""
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? ""
        cuerpo = try c.decodeIfPresent(String.self, forKey: .cuerpo) ?? ""
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaIso = try c.decodeIfPresent(String.self, forKey: .fechaIso)
        leida = try c.decodeIfPresent(Bool.self, forKey: .leida) ?? false
    }
}

struct CentroNotificaciones: Codable {
    let sinLeer: Int
    let notificaciones: [NotificacionCentro]

    enum CodingKeys: String, CodingKey {
        case notificaciones
        case sinLeer = "sin_leer"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sinLeer = try c.decodeIfPresent(Int.self, forKey: .sinLeer) ?? 0
        notificaciones = try c.decodeIfPresent([NotificacionCentro].self, forKey: .notificaciones) ?? []
    }
}

struct HistorialComercio: Codable {
    let comercio: String
    let veces: Int?
    let totalGasto: Double?
    let totalGastoTexto: String?
    let promedio: Double?
    let promedioTexto: String?
    let movimientos: [MovimientoFila]
    let porMes: [HistorialMes]
    let periodo: HistorialPeriodo?

    enum CodingKeys: String, CodingKey {
        case comercio, veces, promedio, movimientos, periodo
        case totalGasto = "total_gasto"
        case totalGastoTexto = "total_gasto_texto"
        case promedioTexto = "promedio_texto"
        case porMes = "por_mes"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        comercio = try c.decodeIfPresent(String.self, forKey: .comercio) ?? ""
        veces = try c.decodeIfPresent(Int.self, forKey: .veces)
        totalGasto = try c.decodeIfPresent(Double.self, forKey: .totalGasto)
        totalGastoTexto = try c.decodeIfPresent(String.self, forKey: .totalGastoTexto)
        promedio = try c.decodeIfPresent(Double.self, forKey: .promedio)
        promedioTexto = try c.decodeIfPresent(String.self, forKey: .promedioTexto)
        movimientos = try c.decodeIfPresent([MovimientoFila].self, forKey: .movimientos) ?? []
        porMes = try c.decodeIfPresent([HistorialMes].self, forKey: .porMes) ?? []
        periodo = try c.decodeIfPresent(HistorialPeriodo.self, forKey: .periodo)
    }
}

struct MensajeOk: Codable {
    let ok: Bool?
    let mensaje: String?
    let message: String?
}

/// El valor flexible de `sin_liquidar` de la simulacion de deudas: un
/// texto o un objeto con nombre/name/comercio.
enum ValorFlexible: Codable {
    case texto(String)
    case objeto(nombre: String)

    init(from decoder: Decoder) throws {
        let contenedor = try decoder.singleValueContainer()
        if let t = try? contenedor.decode(String.self) {
            self = .texto(t)
            return
        }
        struct Obj: Codable {
            let nombre: String?
            let name: String?
            let comercio: String?
        }
        if let o = try? contenedor.decode(Obj.self) {
            self = .objeto(nombre: o.nombre ?? o.name ?? o.comercio ?? "")
            return
        }
        self = .texto("")
    }

    func encode(to encoder: Encoder) throws {
        var contenedor = encoder.singleValueContainer()
        switch self {
        case .texto(let t): try contenedor.encode(t)
        case .objeto(let n): try contenedor.encode(["nombre": n])
        }
    }

    var textoVisible: String {
        switch self {
        case .texto(let t): return t
        case .objeto(let n): return n
        }
    }
}

// MARK: - Presupuesto (pantalla) y Pronostico

// Los DTOs de la pantalla Presupuesto (GET api/v1/presupuesto): forma
// DISTINTA a PresupuestoMes/PresupuestoFila del Panel y de Gastos, que
// son otro contrato. Sin envoltura: el objeto raiz ES la pantalla y
// casi todo importe llega dos veces (numero + texto del servidor).

struct PresupuestoResumen: Codable {
    let totalLimites: Double
    let totalLimitesTexto: String
    let totalGastado: Double
    let totalGastadoTexto: String
    let teQueda: Double
    let teQuedaTexto: String
    let porcentaje: Double?
    let diasRestantes: Int
    let porDia: Double?
    let porDiaTexto: String?

    enum CodingKeys: String, CodingKey {
        case totalLimites = "total_limites"
        case totalLimitesTexto = "total_limites_texto"
        case totalGastado = "total_gastado"
        case totalGastadoTexto = "total_gastado_texto"
        case teQueda = "te_queda"
        case teQuedaTexto = "te_queda_texto"
        case porcentaje
        case diasRestantes = "dias_restantes"
        case porDia = "por_dia"
        case porDiaTexto = "por_dia_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalLimites = try c.decodeIfPresent(Double.self, forKey: .totalLimites) ?? 0
        totalLimitesTexto = try c.decodeIfPresent(String.self, forKey: .totalLimitesTexto) ?? ""
        totalGastado = try c.decodeIfPresent(Double.self, forKey: .totalGastado) ?? 0
        totalGastadoTexto = try c.decodeIfPresent(String.self, forKey: .totalGastadoTexto) ?? ""
        teQueda = try c.decodeIfPresent(Double.self, forKey: .teQueda) ?? 0
        teQuedaTexto = try c.decodeIfPresent(String.self, forKey: .teQuedaTexto) ?? ""
        porcentaje = try c.decodeIfPresent(Double.self, forKey: .porcentaje)
        diasRestantes = try c.decodeIfPresent(Int.self, forKey: .diasRestantes) ?? 0
        porDia = try c.decodeIfPresent(Double.self, forKey: .porDia)
        porDiaTexto = try c.decodeIfPresent(String.self, forKey: .porDiaTexto)
    }

    init(totalLimites: Double = 0, totalLimitesTexto: String = "", totalGastado: Double = 0,
         totalGastadoTexto: String = "", teQueda: Double = 0, teQuedaTexto: String = "",
         porcentaje: Double? = nil, diasRestantes: Int = 0, porDia: Double? = nil, porDiaTexto: String? = nil) {
        self.totalLimites = totalLimites
        self.totalLimitesTexto = totalLimitesTexto
        self.totalGastado = totalGastado
        self.totalGastadoTexto = totalGastadoTexto
        self.teQueda = teQueda
        self.teQuedaTexto = teQuedaTexto
        self.porcentaje = porcentaje
        self.diasRestantes = diasRestantes
        self.porDia = porDia
        self.porDiaTexto = porDiaTexto
    }
}

struct PresupuestoServicios: Codable {
    let esperado: Double
    let esperadoTexto: String
    let cobrado: Double
    let cobradoTexto: String
    let restante: Double
    let restanteTexto: String

    enum CodingKeys: String, CodingKey {
        case esperado, cobrado, restante
        case esperadoTexto = "esperado_texto"
        case cobradoTexto = "cobrado_texto"
        case restanteTexto = "restante_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        esperado = try c.decodeIfPresent(Double.self, forKey: .esperado) ?? 0
        esperadoTexto = try c.decodeIfPresent(String.self, forKey: .esperadoTexto) ?? ""
        cobrado = try c.decodeIfPresent(Double.self, forKey: .cobrado) ?? 0
        cobradoTexto = try c.decodeIfPresent(String.self, forKey: .cobradoTexto) ?? ""
        restante = try c.decodeIfPresent(Double.self, forKey: .restante) ?? 0
        restanteTexto = try c.decodeIfPresent(String.self, forKey: .restanteTexto) ?? ""
    }

    init(esperado: Double = 0, esperadoTexto: String = "", cobrado: Double = 0,
         cobradoTexto: String = "", restante: Double = 0, restanteTexto: String = "") {
        self.esperado = esperado
        self.esperadoTexto = esperadoTexto
        self.cobrado = cobrado
        self.cobradoTexto = cobradoTexto
        self.restante = restante
        self.restanteTexto = restanteTexto
    }
}

struct PresupuestoIngresos: Codable {
    let total: Double
    let totalTexto: String

    enum CodingKeys: String, CodingKey {
        case total
        case totalTexto = "total_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try c.decodeIfPresent(Double.self, forKey: .total) ?? 0
        totalTexto = try c.decodeIfPresent(String.self, forKey: .totalTexto) ?? ""
    }

    init(total: Double = 0, totalTexto: String = "") {
        self.total = total
        self.totalTexto = totalTexto
    }
}

/// La meta de ahorro dentro de Presupuesto: sin meta el servidor manda
/// solo {"hay_meta": false} y todo lo demas llega ausente (opcional).
struct MetaAhorroPresupuesto: Codable {
    let hayMeta: Bool
    let id: Int?
    let nombre: String?
    let objetivo: Double?
    let objetivoTexto: String?
    let ahorrado: Double?
    let ahorradoTexto: String?
    let porcentaje: Double?
    let proyectado: Double?
    let proyectadoTexto: String?
    let mensaje: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, objetivo, ahorrado, porcentaje, proyectado, mensaje
        case hayMeta = "hay_meta"
        case objetivoTexto = "objetivo_texto"
        case ahorradoTexto = "ahorrado_texto"
        case proyectadoTexto = "proyectado_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hayMeta = try c.decodeIfPresent(Bool.self, forKey: .hayMeta) ?? false
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre)
        objetivo = try c.decodeIfPresent(Double.self, forKey: .objetivo)
        objetivoTexto = try c.decodeIfPresent(String.self, forKey: .objetivoTexto)
        ahorrado = try c.decodeIfPresent(Double.self, forKey: .ahorrado)
        ahorradoTexto = try c.decodeIfPresent(String.self, forKey: .ahorradoTexto)
        porcentaje = try c.decodeIfPresent(Double.self, forKey: .porcentaje)
        proyectado = try c.decodeIfPresent(Double.self, forKey: .proyectado)
        proyectadoTexto = try c.decodeIfPresent(String.self, forKey: .proyectadoTexto)
        mensaje = try c.decodeIfPresent(String.self, forKey: .mensaje)
    }

    init(hayMeta: Bool = false, id: Int? = nil, nombre: String? = nil, objetivo: Double? = nil,
         objetivoTexto: String? = nil, ahorrado: Double? = nil, ahorradoTexto: String? = nil,
         porcentaje: Double? = nil, proyectado: Double? = nil, proyectadoTexto: String? = nil,
         mensaje: String? = nil) {
        self.hayMeta = hayMeta
        self.id = id
        self.nombre = nombre
        self.objetivo = objetivo
        self.objetivoTexto = objetivoTexto
        self.ahorrado = ahorrado
        self.ahorradoTexto = ahorradoTexto
        self.porcentaje = porcentaje
        self.proyectado = proyectado
        self.proyectadoTexto = proyectadoTexto
        self.mensaje = mensaje
    }
}

struct HistorialPresupuesto: Codable {
    let etiqueta: String
    let gastado: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        gastado = try c.decodeIfPresent(Double.self, forKey: .gastado) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case etiqueta, gastado
    }

    init(etiqueta: String = "", gastado: Double = 0) {
        self.etiqueta = etiqueta
        self.gastado = gastado
    }
}

/// Una fila de la pantalla Presupuesto: categoria con tope o solo con
/// gasto. `id` es el id del Budget (null sin tope) y lo usa el DELETE;
/// `limite` ya viene EFECTIVO (con rollover aplicado): la fila no trae
/// el limite base ni el rollover, y la app no los muestra ni los edita.
struct PresupuestoPantallaFila: Codable, Identifiable {
    var idFila: String { categoria }
    let id: Int?
    let categoria: String
    let etiqueta: String
    let categoriaColor: String
    let categoriaIcono: String
    let gastado: Double
    let gastadoTexto: String
    let mesPasado: Double
    let mesPasadoTexto: String
    let limite: Double?
    let limiteTexto: String?
    let queda: Double?
    let quedaTexto: String?
    let porcentaje: Double?
    let alerta: String?
    let historial: [HistorialPresupuesto]

    enum CodingKeys: String, CodingKey {
        case id, categoria, etiqueta, gastado, limite, queda, porcentaje, alerta, historial
        case categoriaColor = "categoria_color"
        case categoriaIcono = "categoria_icono"
        case gastadoTexto = "gastado_texto"
        case mesPasado = "mes_pasado"
        case mesPasadoTexto = "mes_pasado_texto"
        case limiteTexto = "limite_texto"
        case quedaTexto = "queda_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id)
        categoria = try c.decodeIfPresent(String.self, forKey: .categoria) ?? ""
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        categoriaColor = try c.decodeIfPresent(String.self, forKey: .categoriaColor) ?? ""
        categoriaIcono = try c.decodeIfPresent(String.self, forKey: .categoriaIcono) ?? "etiqueta"
        gastado = try c.decodeIfPresent(Double.self, forKey: .gastado) ?? 0
        gastadoTexto = try c.decodeIfPresent(String.self, forKey: .gastadoTexto) ?? ""
        mesPasado = try c.decodeIfPresent(Double.self, forKey: .mesPasado) ?? 0
        mesPasadoTexto = try c.decodeIfPresent(String.self, forKey: .mesPasadoTexto) ?? ""
        limite = try c.decodeIfPresent(Double.self, forKey: .limite)
        limiteTexto = try c.decodeIfPresent(String.self, forKey: .limiteTexto)
        queda = try c.decodeIfPresent(Double.self, forKey: .queda)
        quedaTexto = try c.decodeIfPresent(String.self, forKey: .quedaTexto)
        porcentaje = try c.decodeIfPresent(Double.self, forKey: .porcentaje)
        alerta = try c.decodeIfPresent(String.self, forKey: .alerta)
        historial = try c.decodeIfPresent([HistorialPresupuesto].self, forKey: .historial) ?? []
    }
}

/// El grupo "Todo lo demas": subconjunto de `filas` (las sin tope y con
/// gasto). No sumarlas otra vez a ningun total.
struct TodoLoDemas: Codable {
    let gastado: Double
    let gastadoTexto: String
    let cantidad: Int
    let filas: [PresupuestoPantallaFila]

    enum CodingKeys: String, CodingKey {
        case gastado, cantidad, filas
        case gastadoTexto = "gastado_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gastado = try c.decodeIfPresent(Double.self, forKey: .gastado) ?? 0
        gastadoTexto = try c.decodeIfPresent(String.self, forKey: .gastadoTexto) ?? ""
        cantidad = try c.decodeIfPresent(Int.self, forKey: .cantidad) ?? 0
        filas = try c.decodeIfPresent([PresupuestoPantallaFila].self, forKey: .filas) ?? []
    }

    init(gastado: Double = 0, gastadoTexto: String = "", cantidad: Int = 0, filas: [PresupuestoPantallaFila] = []) {
        self.gastado = gastado
        self.gastadoTexto = gastadoTexto
        self.cantidad = cantidad
        self.filas = filas
    }
}

/// El plan del mes: el ingreso esperado guardado puede ser null (nunca
/// fijado) y entonces el efectivo es el ingreso del mes pasado
/// (ingreso_es_sugerido). Las tarjetas pintan el EFECTIVO; la hoja de
/// ingreso precarga el GUARDADO.
struct PlanPresupuesto: Codable {
    let ingresoEsperado: Double?
    let ingresoEsperadoTexto: String?
    let ingresoEsSugerido: Bool
    let ingresoMesPasado: Double
    let ingresoMesPasadoTexto: String
    let ingresoEfectivo: Double
    let ingresoEfectivoTexto: String
    let totalAsignado: Double
    let totalAsignadoTexto: String
    let pagoDeudas: Double
    let pagoDeudasTexto: String
    let pagoDeudasMinimos: Double
    let pagoDeudasMinimosTexto: String
    let pagoDeudasExtra: Double
    let pagoDeudasExtraTexto: String
    let quedaParaAhorro: Double
    let quedaParaAhorroTexto: String
    let sobreComprometido: Bool

    enum CodingKeys: String, CodingKey {
        case ingresoEsSugerido = "ingreso_es_sugerido"
        case ingresoEsperado = "ingreso_esperado"
        case ingresoEsperadoTexto = "ingreso_esperado_texto"
        case ingresoMesPasado = "ingreso_mes_pasado"
        case ingresoMesPasadoTexto = "ingreso_mes_pasado_texto"
        case ingresoEfectivo = "ingreso_efectivo"
        case ingresoEfectivoTexto = "ingreso_efectivo_texto"
        case totalAsignado = "total_asignado"
        case totalAsignadoTexto = "total_asignado_texto"
        case pagoDeudas = "pago_deudas"
        case pagoDeudasTexto = "pago_deudas_texto"
        case pagoDeudasMinimos = "pago_deudas_minimos"
        case pagoDeudasMinimosTexto = "pago_deudas_minimos_texto"
        case pagoDeudasExtra = "pago_deudas_extra"
        case pagoDeudasExtraTexto = "pago_deudas_extra_texto"
        case quedaParaAhorro = "queda_para_ahorro"
        case quedaParaAhorroTexto = "queda_para_ahorro_texto"
        case sobreComprometido = "sobre_comprometido"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ingresoEsperado = try c.decodeIfPresent(Double.self, forKey: .ingresoEsperado)
        ingresoEsperadoTexto = try c.decodeIfPresent(String.self, forKey: .ingresoEsperadoTexto)
        ingresoEsSugerido = try c.decodeIfPresent(Bool.self, forKey: .ingresoEsSugerido) ?? true
        ingresoMesPasado = try c.decodeIfPresent(Double.self, forKey: .ingresoMesPasado) ?? 0
        ingresoMesPasadoTexto = try c.decodeIfPresent(String.self, forKey: .ingresoMesPasadoTexto) ?? ""
        ingresoEfectivo = try c.decodeIfPresent(Double.self, forKey: .ingresoEfectivo) ?? 0
        ingresoEfectivoTexto = try c.decodeIfPresent(String.self, forKey: .ingresoEfectivoTexto) ?? ""
        totalAsignado = try c.decodeIfPresent(Double.self, forKey: .totalAsignado) ?? 0
        totalAsignadoTexto = try c.decodeIfPresent(String.self, forKey: .totalAsignadoTexto) ?? ""
        pagoDeudas = try c.decodeIfPresent(Double.self, forKey: .pagoDeudas) ?? 0
        pagoDeudasTexto = try c.decodeIfPresent(String.self, forKey: .pagoDeudasTexto) ?? ""
        pagoDeudasMinimos = try c.decodeIfPresent(Double.self, forKey: .pagoDeudasMinimos) ?? 0
        pagoDeudasMinimosTexto = try c.decodeIfPresent(String.self, forKey: .pagoDeudasMinimosTexto) ?? ""
        pagoDeudasExtra = try c.decodeIfPresent(Double.self, forKey: .pagoDeudasExtra) ?? 0
        pagoDeudasExtraTexto = try c.decodeIfPresent(String.self, forKey: .pagoDeudasExtraTexto) ?? ""
        quedaParaAhorro = try c.decodeIfPresent(Double.self, forKey: .quedaParaAhorro) ?? 0
        quedaParaAhorroTexto = try c.decodeIfPresent(String.self, forKey: .quedaParaAhorroTexto) ?? ""
        sobreComprometido = try c.decodeIfPresent(Bool.self, forKey: .sobreComprometido) ?? false
    }

    init(ingresoEsperado: Double? = nil, ingresoEsperadoTexto: String? = nil, ingresoEsSugerido: Bool = true,
         ingresoMesPasado: Double = 0, ingresoMesPasadoTexto: String = "", ingresoEfectivo: Double = 0,
         ingresoEfectivoTexto: String = "", totalAsignado: Double = 0, totalAsignadoTexto: String = "",
         pagoDeudas: Double = 0, pagoDeudasTexto: String = "", pagoDeudasMinimos: Double = 0,
         pagoDeudasMinimosTexto: String = "", pagoDeudasExtra: Double = 0, pagoDeudasExtraTexto: String = "",
         quedaParaAhorro: Double = 0, quedaParaAhorroTexto: String = "", sobreComprometido: Bool = false) {
        self.ingresoEsperado = ingresoEsperado
        self.ingresoEsperadoTexto = ingresoEsperadoTexto
        self.ingresoEsSugerido = ingresoEsSugerido
        self.ingresoMesPasado = ingresoMesPasado
        self.ingresoMesPasadoTexto = ingresoMesPasadoTexto
        self.ingresoEfectivo = ingresoEfectivo
        self.ingresoEfectivoTexto = ingresoEfectivoTexto
        self.totalAsignado = totalAsignado
        self.totalAsignadoTexto = totalAsignadoTexto
        self.pagoDeudas = pagoDeudas
        self.pagoDeudasTexto = pagoDeudasTexto
        self.pagoDeudasMinimos = pagoDeudasMinimos
        self.pagoDeudasMinimosTexto = pagoDeudasMinimosTexto
        self.pagoDeudasExtra = pagoDeudasExtra
        self.pagoDeudasExtraTexto = pagoDeudasExtraTexto
        self.quedaParaAhorro = quedaParaAhorro
        self.quedaParaAhorroTexto = quedaParaAhorroTexto
        self.sobreComprometido = sobreComprometido
    }
}

struct CierreFila: Codable, Identifiable {
    var id: String { clave }
    let clave: String
    let etiqueta: String
    let categoriaColor: String
    let categoriaIcono: String
    let limite: Double
    let limiteTexto: String
    let gastado: Double
    let gastadoTexto: String
    let diferencia: Double
    let diferenciaTexto: String
    let veredicto: String

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, limite, gastado, diferencia, veredicto
        case categoriaColor = "categoria_color"
        case categoriaIcono = "categoria_icono"
        case limiteTexto = "limite_texto"
        case gastadoTexto = "gastado_texto"
        case diferenciaTexto = "diferencia_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        categoriaColor = try c.decodeIfPresent(String.self, forKey: .categoriaColor) ?? ""
        categoriaIcono = try c.decodeIfPresent(String.self, forKey: .categoriaIcono) ?? "etiqueta"
        limite = try c.decodeIfPresent(Double.self, forKey: .limite) ?? 0
        limiteTexto = try c.decodeIfPresent(String.self, forKey: .limiteTexto) ?? ""
        gastado = try c.decodeIfPresent(Double.self, forKey: .gastado) ?? 0
        gastadoTexto = try c.decodeIfPresent(String.self, forKey: .gastadoTexto) ?? ""
        diferencia = try c.decodeIfPresent(Double.self, forKey: .diferencia) ?? 0
        diferenciaTexto = try c.decodeIfPresent(String.self, forKey: .diferenciaTexto) ?? ""
        veredicto = try c.decodeIfPresent(String.self, forKey: .veredicto) ?? "sin_limite"
    }
}

/// El cierre de un mes pasado; en mes actual o futuro `cierre` = null.
/// total_limite y total_gastado llegan SIN su *_texto.
struct CierrePresupuesto: Codable {
    let hayFoto: Bool
    let entro: Double
    let entroTexto: String
    let salio: Double
    let salioTexto: String
    let teQuedo: Double
    let teQuedoTexto: String
    let totalLimite: Double
    let totalGastado: Double
    let filas: [CierreFila]

    enum CodingKeys: String, CodingKey {
        case entro, salio, filas
        case hayFoto = "hay_foto"
        case entroTexto = "entro_texto"
        case salioTexto = "salio_texto"
        case teQuedo = "te_quedo"
        case teQuedoTexto = "te_quedo_texto"
        case totalLimite = "total_limite"
        case totalGastado = "total_gastado"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hayFoto = try c.decodeIfPresent(Bool.self, forKey: .hayFoto) ?? false
        entro = try c.decodeIfPresent(Double.self, forKey: .entro) ?? 0
        entroTexto = try c.decodeIfPresent(String.self, forKey: .entroTexto) ?? ""
        salio = try c.decodeIfPresent(Double.self, forKey: .salio) ?? 0
        salioTexto = try c.decodeIfPresent(String.self, forKey: .salioTexto) ?? ""
        teQuedo = try c.decodeIfPresent(Double.self, forKey: .teQuedo) ?? 0
        teQuedoTexto = try c.decodeIfPresent(String.self, forKey: .teQuedoTexto) ?? ""
        totalLimite = try c.decodeIfPresent(Double.self, forKey: .totalLimite) ?? 0
        totalGastado = try c.decodeIfPresent(Double.self, forKey: .totalGastado) ?? 0
        filas = try c.decodeIfPresent([CierreFila].self, forKey: .filas) ?? []
    }

    init(hayFoto: Bool = false, entro: Double = 0, entroTexto: String = "", salio: Double = 0,
         salioTexto: String = "", teQuedo: Double = 0, teQuedoTexto: String = "",
         totalLimite: Double = 0, totalGastado: Double = 0, filas: [CierreFila] = []) {
        self.hayFoto = hayFoto
        self.entro = entro
        self.entroTexto = entroTexto
        self.salio = salio
        self.salioTexto = salioTexto
        self.teQuedo = teQuedo
        self.teQuedoTexto = teQuedoTexto
        self.totalLimite = totalLimite
        self.totalGastado = totalGastado
        self.filas = filas
    }
}

/// Una categoria del catalogo para poner topes. Ojo: aqui el color se
/// llama `color` y el icono `icono` (en las filas es categoria_color /
/// categoria_icono).
struct CategoriaDisponible: Codable, Identifiable {
    var id: String { clave }
    let clave: String
    let etiqueta: String
    let icono: String
    let color: String
    let promedio: Double
    let promedioTexto: String

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, icono, color, promedio
        case promedioTexto = "promedio_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        icono = try c.decodeIfPresent(String.self, forKey: .icono) ?? "etiqueta"
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? ""
        promedio = try c.decodeIfPresent(Double.self, forKey: .promedio) ?? 0
        promedioTexto = try c.decodeIfPresent(String.self, forKey: .promedioTexto) ?? ""
    }

    init(clave: String = "", etiqueta: String = "", icono: String = "etiqueta", color: String = "",
         promedio: Double = 0, promedioTexto: String = "") {
        self.clave = clave
        self.etiqueta = etiqueta
        self.icono = icono
        self.color = color
        self.promedio = promedio
        self.promedioTexto = promedioTexto
    }
}

/// La pantalla Presupuesto entera (respuesta de GET y de TODAS las
/// escrituras: cada guardado devuelve la pantalla recalculada y el
/// modelo la sustituye).
struct PresupuestoPantalla: Codable {
    let mes: String
    let mesEtiqueta: String
    let esMesActual: Bool
    let hayPresupuesto: Bool
    let resumen: PresupuestoResumen
    let servicios: PresupuestoServicios
    let ingresos: PresupuestoIngresos
    let metaAhorro: MetaAhorroPresupuesto
    let filas: [PresupuestoPantallaFila]
    let todoLoDemas: TodoLoDemas
    let plan: PlanPresupuesto
    let cierre: CierrePresupuesto?
    let categoriasDisponibles: [CategoriaDisponible]

    enum CodingKeys: String, CodingKey {
        case mes, resumen, servicios, ingresos, filas, plan, cierre
        case mesEtiqueta = "mes_etiqueta"
        case esMesActual = "es_mes_actual"
        case hayPresupuesto = "hay_presupuesto"
        case metaAhorro = "meta_ahorro"
        case todoLoDemas = "todo_lo_demas"
        case categoriasDisponibles = "categorias_disponibles"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mes = try c.decodeIfPresent(String.self, forKey: .mes) ?? ""
        mesEtiqueta = try c.decodeIfPresent(String.self, forKey: .mesEtiqueta) ?? ""
        esMesActual = try c.decodeIfPresent(Bool.self, forKey: .esMesActual) ?? false
        hayPresupuesto = try c.decodeIfPresent(Bool.self, forKey: .hayPresupuesto) ?? false
        resumen = try c.decodeIfPresent(PresupuestoResumen.self, forKey: .resumen) ?? PresupuestoResumen()
        servicios = try c.decodeIfPresent(PresupuestoServicios.self, forKey: .servicios) ?? PresupuestoServicios()
        ingresos = try c.decodeIfPresent(PresupuestoIngresos.self, forKey: .ingresos) ?? PresupuestoIngresos()
        metaAhorro = try c.decodeIfPresent(MetaAhorroPresupuesto.self, forKey: .metaAhorro) ?? MetaAhorroPresupuesto()
        filas = try c.decodeIfPresent([PresupuestoPantallaFila].self, forKey: .filas) ?? []
        todoLoDemas = try c.decodeIfPresent(TodoLoDemas.self, forKey: .todoLoDemas) ?? TodoLoDemas()
        plan = try c.decodeIfPresent(PlanPresupuesto.self, forKey: .plan) ?? PlanPresupuesto()
        cierre = try c.decodeIfPresent(CierrePresupuesto.self, forKey: .cierre)
        categoriasDisponibles = try c.decodeIfPresent([CategoriaDisponible].self, forKey: .categoriasDisponibles) ?? []
    }
}

// MARK: - Pronostico

struct PronosticoPunto: Codable {
    let fecha: String
    let saldo: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        saldo = try c.decodeIfPresent(Double.self, forKey: .saldo) ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case fecha, saldo
    }

    init(fecha: String = "", saldo: Double = 0) {
        self.fecha = fecha
        self.saldo = saldo
    }
}

struct PronosticoCuenta: Codable, Identifiable {
    var id: String { nombre }
    let nombre: String
    let saldoInicial: Double
    let saldoInicialTexto: String
    let saldoFinal: Double
    let saldoFinalTexto: String

    enum CodingKeys: String, CodingKey {
        case nombre
        case saldoInicial = "saldo_inicial"
        case saldoInicialTexto = "saldo_inicial_texto"
        case saldoFinal = "saldo_final"
        case saldoFinalTexto = "saldo_final_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        saldoInicial = try c.decodeIfPresent(Double.self, forKey: .saldoInicial) ?? 0
        saldoInicialTexto = try c.decodeIfPresent(String.self, forKey: .saldoInicialTexto) ?? ""
        saldoFinal = try c.decodeIfPresent(Double.self, forKey: .saldoFinal) ?? 0
        saldoFinalTexto = try c.decodeIfPresent(String.self, forKey: .saldoFinalTexto) ?? ""
    }
}

/// Un evento que viene: la UI no distingue por `tipo`, distingue por el
/// SIGNO de `monto` (positivo entra, negativo sale). monto puede ser null.
struct PronosticoEvento: Codable {
    let fecha: String
    let fechaTexto: String
    let tipo: String
    let titulo: String
    let cuentaTexto: String?
    let monto: Double?
    let montoTexto: String?

    enum CodingKeys: String, CodingKey {
        case fecha, tipo, titulo, monto
        case fechaTexto = "fecha_texto"
        case cuentaTexto = "cuenta_texto"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaTexto = try c.decodeIfPresent(String.self, forKey: .fechaTexto) ?? ""
        tipo = try c.decodeIfPresent(String.self, forKey: .tipo) ?? ""
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? ""
        cuentaTexto = try c.decodeIfPresent(String.self, forKey: .cuentaTexto)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto)
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto)
    }
}

/// La comparacion con/sin plan de deudas (solo llega con plan aplicado;
/// varios campos la UI no los pinta, pero el DTO los trae completos).
struct ComparacionPlan: Codable {
    let estrategia: String
    let extra: Double
    let extraTexto: String
    let presupuestoMensual: Double
    let presupuestoMensualTexto: String
    let sumaMinimos: Double
    let sumaMinimosTexto: String
    let fechaLibreConPlan: String?
    let fechaLibreConPlanTexto: String?
    let fechaLibreSinPlan: String?
    let fechaLibreSinPlanTexto: String?
    let interesConPlan: Double
    let interesConPlanTexto: String
    let interesSinPlan: Double
    let interesSinPlanTexto: String
    let interesAhorrado: Double
    let interesAhorradoTexto: String

    enum CodingKeys: String, CodingKey {
        case estrategia, extra
        case extraTexto = "extra_texto"
        case presupuestoMensual = "presupuesto_mensual"
        case presupuestoMensualTexto = "presupuesto_mensual_texto"
        case sumaMinimos = "suma_minimos"
        case sumaMinimosTexto = "suma_minimos_texto"
        case fechaLibreConPlan = "fecha_libre_con_plan"
        case fechaLibreConPlanTexto = "fecha_libre_con_plan_texto"
        case fechaLibreSinPlan = "fecha_libre_sin_plan"
        case fechaLibreSinPlanTexto = "fecha_libre_sin_plan_texto"
        case interesConPlan = "interes_con_plan"
        case interesConPlanTexto = "interes_con_plan_texto"
        case interesSinPlan = "interes_sin_plan"
        case interesSinPlanTexto = "interes_sin_plan_texto"
        case interesAhorrado = "interes_ahorrado"
        case interesAhorradoTexto = "interes_ahorrado_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estrategia = try c.decodeIfPresent(String.self, forKey: .estrategia) ?? ""
        extra = try c.decodeIfPresent(Double.self, forKey: .extra) ?? 0
        extraTexto = try c.decodeIfPresent(String.self, forKey: .extraTexto) ?? ""
        presupuestoMensual = try c.decodeIfPresent(Double.self, forKey: .presupuestoMensual) ?? 0
        presupuestoMensualTexto = try c.decodeIfPresent(String.self, forKey: .presupuestoMensualTexto) ?? ""
        sumaMinimos = try c.decodeIfPresent(Double.self, forKey: .sumaMinimos) ?? 0
        sumaMinimosTexto = try c.decodeIfPresent(String.self, forKey: .sumaMinimosTexto) ?? ""
        fechaLibreConPlan = try c.decodeIfPresent(String.self, forKey: .fechaLibreConPlan)
        fechaLibreConPlanTexto = try c.decodeIfPresent(String.self, forKey: .fechaLibreConPlanTexto)
        fechaLibreSinPlan = try c.decodeIfPresent(String.self, forKey: .fechaLibreSinPlan)
        fechaLibreSinPlanTexto = try c.decodeIfPresent(String.self, forKey: .fechaLibreSinPlanTexto)
        interesConPlan = try c.decodeIfPresent(Double.self, forKey: .interesConPlan) ?? 0
        interesConPlanTexto = try c.decodeIfPresent(String.self, forKey: .interesConPlanTexto) ?? ""
        interesSinPlan = try c.decodeIfPresent(Double.self, forKey: .interesSinPlan) ?? 0
        interesSinPlanTexto = try c.decodeIfPresent(String.self, forKey: .interesSinPlanTexto) ?? ""
        interesAhorrado = try c.decodeIfPresent(Double.self, forKey: .interesAhorrado) ?? 0
        interesAhorradoTexto = try c.decodeIfPresent(String.self, forKey: .interesAhorradoTexto) ?? ""
    }
}

/// El Pronostico entero (GET api/v1/pronostico): el servidor calcula la
/// serie diaria, el minimo, la alerta y los totales; la app solo pinta
/// y escala la grafica con los puntos dados.
struct Pronostico: Codable {
    let meses: Int
    let conPlan: Bool
    let tienePlan: Bool
    let tieneDeudas: Bool
    let avisoPlan: String?
    let saldoInicial: Double
    let saldoInicialTexto: String
    let saldoFinal: Double
    let saldoFinalTexto: String
    let saldoMinimo: Double
    let saldoMinimoTexto: String
    let fechaSaldoMinimo: String
    let fechaSaldoMinimoTexto: String
    let alertaFecha: String?
    let alertaFechaTexto: String?
    let totalIngresos: Double
    let totalIngresosTexto: String
    let totalEgresos: Double
    let totalEgresosTexto: String
    let serie: [PronosticoPunto]
    let porCuenta: [PronosticoCuenta]
    let eventos: [PronosticoEvento]
    let comparacion: ComparacionPlan?

    enum CodingKeys: String, CodingKey {
        case meses, serie, eventos, comparacion
        case conPlan = "con_plan"
        case tienePlan = "tiene_plan"
        case tieneDeudas = "tiene_deudas"
        case avisoPlan = "aviso_plan"
        case saldoInicial = "saldo_inicial"
        case saldoInicialTexto = "saldo_inicial_texto"
        case saldoFinal = "saldo_final"
        case saldoFinalTexto = "saldo_final_texto"
        case saldoMinimo = "saldo_minimo"
        case saldoMinimoTexto = "saldo_minimo_texto"
        case fechaSaldoMinimo = "fecha_saldo_minimo"
        case fechaSaldoMinimoTexto = "fecha_saldo_minimo_texto"
        case alertaFecha = "alerta_fecha"
        case alertaFechaTexto = "alerta_fecha_texto"
        case totalIngresos = "total_ingresos"
        case totalIngresosTexto = "total_ingresos_texto"
        case totalEgresos = "total_egresos"
        case totalEgresosTexto = "total_egresos_texto"
        case porCuenta = "por_cuenta"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meses = try c.decodeIfPresent(Int.self, forKey: .meses) ?? 3
        conPlan = try c.decodeIfPresent(Bool.self, forKey: .conPlan) ?? false
        tienePlan = try c.decodeIfPresent(Bool.self, forKey: .tienePlan) ?? false
        tieneDeudas = try c.decodeIfPresent(Bool.self, forKey: .tieneDeudas) ?? false
        avisoPlan = try c.decodeIfPresent(String.self, forKey: .avisoPlan)
        saldoInicial = try c.decodeIfPresent(Double.self, forKey: .saldoInicial) ?? 0
        saldoInicialTexto = try c.decodeIfPresent(String.self, forKey: .saldoInicialTexto) ?? ""
        saldoFinal = try c.decodeIfPresent(Double.self, forKey: .saldoFinal) ?? 0
        saldoFinalTexto = try c.decodeIfPresent(String.self, forKey: .saldoFinalTexto) ?? ""
        saldoMinimo = try c.decodeIfPresent(Double.self, forKey: .saldoMinimo) ?? 0
        saldoMinimoTexto = try c.decodeIfPresent(String.self, forKey: .saldoMinimoTexto) ?? ""
        fechaSaldoMinimo = try c.decodeIfPresent(String.self, forKey: .fechaSaldoMinimo) ?? ""
        fechaSaldoMinimoTexto = try c.decodeIfPresent(String.self, forKey: .fechaSaldoMinimoTexto) ?? ""
        alertaFecha = try c.decodeIfPresent(String.self, forKey: .alertaFecha)
        alertaFechaTexto = try c.decodeIfPresent(String.self, forKey: .alertaFechaTexto)
        totalIngresos = try c.decodeIfPresent(Double.self, forKey: .totalIngresos) ?? 0
        totalIngresosTexto = try c.decodeIfPresent(String.self, forKey: .totalIngresosTexto) ?? ""
        totalEgresos = try c.decodeIfPresent(Double.self, forKey: .totalEgresos) ?? 0
        totalEgresosTexto = try c.decodeIfPresent(String.self, forKey: .totalEgresosTexto) ?? ""
        serie = try c.decodeIfPresent([PronosticoPunto].self, forKey: .serie) ?? []
        porCuenta = try c.decodeIfPresent([PronosticoCuenta].self, forKey: .porCuenta) ?? []
        eventos = try c.decodeIfPresent([PronosticoEvento].self, forKey: .eventos) ?? []
        comparacion = try c.decodeIfPresent(ComparacionPlan.self, forKey: .comparacion)
    }
}

// MARK: - Patrimonio y Metas (mapa-patrimonio-metas.md)

/// La foto completa de Patrimonio (GET/POST/PUT/DELETE de
/// api/v1/patrimonio…): sin envoltura. Las tres series comparten el
/// punto del Panel (`PuntoPatrimonio`): en `serieActivos` y
/// `serieDeudas` el campo `neto` trae el total de ese lado.
struct PatrimonioDto: Codable {
    let rango: String
    let rangosDisponibles: [String]
    let neto: Double
    let netoTexto: String
    let activos: Double
    let activosTexto: String
    let deudas: Double
    let deudasTexto: String
    let cambio: Double?
    let cambioTexto: String?
    let cambioActivos: Double?
    let cambioActivosTexto: String?
    let cambioDeudas: Double?
    let cambioDeudasTexto: String?
    let serie: [PuntoPatrimonio]
    let serieActivos: [PuntoPatrimonio]
    let serieDeudas: [PuntoPatrimonio]
    let activosGrupos: [PatrimonioGrupoDto]
    let deudasGrupos: [PatrimonioGrupoDto]
    let bienes: [BienManualDto]
    let sinDatos: Bool

    enum CodingKeys: String, CodingKey {
        case rango, neto, activos, deudas, cambio, serie, bienes
        case rangosDisponibles = "rangos_disponibles"
        case netoTexto = "neto_texto"
        case activosTexto = "activos_texto"
        case deudasTexto = "deudas_texto"
        case cambioTexto = "cambio_texto"
        case cambioActivos = "cambio_activos"
        case cambioActivosTexto = "cambio_activos_texto"
        case cambioDeudas = "cambio_deudas"
        case cambioDeudasTexto = "cambio_deudas_texto"
        case serieActivos = "serie_activos"
        case serieDeudas = "serie_deudas"
        case activosGrupos = "activos_grupos"
        case deudasGrupos = "deudas_grupos"
        case sinDatos = "sin_datos"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rango = try c.decodeIfPresent(String.self, forKey: .rango) ?? "3M"
        rangosDisponibles = try c.decodeIfPresent([String].self, forKey: .rangosDisponibles) ?? []
        neto = try c.decodeIfPresent(Double.self, forKey: .neto) ?? 0
        netoTexto = try c.decodeIfPresent(String.self, forKey: .netoTexto) ?? ""
        activos = try c.decodeIfPresent(Double.self, forKey: .activos) ?? 0
        activosTexto = try c.decodeIfPresent(String.self, forKey: .activosTexto) ?? ""
        deudas = try c.decodeIfPresent(Double.self, forKey: .deudas) ?? 0
        deudasTexto = try c.decodeIfPresent(String.self, forKey: .deudasTexto) ?? ""
        cambio = try c.decodeIfPresent(Double.self, forKey: .cambio)
        cambioTexto = try c.decodeIfPresent(String.self, forKey: .cambioTexto)
        cambioActivos = try c.decodeIfPresent(Double.self, forKey: .cambioActivos)
        cambioActivosTexto = try c.decodeIfPresent(String.self, forKey: .cambioActivosTexto)
        cambioDeudas = try c.decodeIfPresent(Double.self, forKey: .cambioDeudas)
        cambioDeudasTexto = try c.decodeIfPresent(String.self, forKey: .cambioDeudasTexto)
        serie = try c.decodeIfPresent([PuntoPatrimonio].self, forKey: .serie) ?? []
        serieActivos = try c.decodeIfPresent([PuntoPatrimonio].self, forKey: .serieActivos) ?? []
        serieDeudas = try c.decodeIfPresent([PuntoPatrimonio].self, forKey: .serieDeudas) ?? []
        activosGrupos = try c.decodeIfPresent([PatrimonioGrupoDto].self, forKey: .activosGrupos) ?? []
        deudasGrupos = try c.decodeIfPresent([PatrimonioGrupoDto].self, forKey: .deudasGrupos) ?? []
        bienes = try c.decodeIfPresent([BienManualDto].self, forKey: .bienes) ?? []
        sinDatos = try c.decodeIfPresent(Bool.self, forKey: .sinDatos) ?? false
    }
}

/// Un grupo de la clasificacion por tipo (una de las 8 claves); la
/// etiqueta la manda el servidor y se pinta tal cual.
struct PatrimonioGrupoDto: Codable, Identifiable {
    var id: String { clave }
    let clave: String
    let etiqueta: String
    let subtotal: Double
    let subtotalTexto: String
    let pct: Double
    let items: [PatrimonioItemDto]

    enum CodingKeys: String, CodingKey {
        case clave, etiqueta, subtotal, pct, items
        case subtotalTexto = "subtotal_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        clave = try c.decodeIfPresent(String.self, forKey: .clave) ?? ""
        etiqueta = try c.decodeIfPresent(String.self, forKey: .etiqueta) ?? ""
        subtotal = try c.decodeIfPresent(Double.self, forKey: .subtotal) ?? 0
        subtotalTexto = try c.decodeIfPresent(String.self, forKey: .subtotalTexto) ?? ""
        pct = try c.decodeIfPresent(Double.self, forKey: .pct) ?? 0
        items = try c.decodeIfPresent([PatrimonioItemDto].self, forKey: .items) ?? []
    }
}

struct PatrimonioItemDto: Codable {
    let nombre: String
    let monto: Double
    let montoTexto: String
    /// En items de activo el servidor ni manda la clave (llega nil).
    let detalle: String?
    /// Solo en items que salen de un registro Debt; la UI no lo usa.
    let deudaId: Int?
    /// La llave para abrir la edicion: se cruza contra `bienes`.
    let manualId: Int?

    enum CodingKeys: String, CodingKey {
        case nombre, monto, detalle
        case montoTexto = "monto_texto"
        case deudaId = "deuda_id"
        case manualId = "manual_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        detalle = try c.decodeIfPresent(String.self, forKey: .detalle)
        deudaId = try c.decodeIfPresent(Int.self, forKey: .deudaId)
        manualId = try c.decodeIfPresent(Int.self, forKey: .manualId)
    }
}

/// El registro editable detras de los items con `manualId`.
struct BienManualDto: Codable, Identifiable {
    let id: Int
    let nombre: String
    let kind: String
    let grupo: String?
    let monto: Double
    let montoTexto: String
    let conPrestamo: Bool

    enum CodingKeys: String, CodingKey {
        case id, nombre, kind, grupo, monto
        case montoTexto = "monto_texto"
        case conPrestamo = "con_prestamo"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? ""
        grupo = try c.decodeIfPresent(String.self, forKey: .grupo)
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        conPrestamo = try c.decodeIfPresent(Bool.self, forKey: .conPrestamo) ?? false
    }
}

/// La respuesta de GET api/v1/metas (sin envoltura).
struct MetasDto: Codable {
    let metas: [MetaDto]
    let archivadas: [MetaDto]
    let cuentas: [CuentaSimpleDto]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        metas = try c.decodeIfPresent([MetaDto].self, forKey: .metas) ?? []
        archivadas = try c.decodeIfPresent([MetaDto].self, forKey: .archivadas) ?? []
        cuentas = try c.decodeIfPresent([CuentaSimpleDto].self, forKey: .cuentas) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case metas, archivadas, cuentas
    }
}

struct MetaDto: Codable, Identifiable {
    let id: Int
    let nombre: String
    /// Sale de `monto_objetivo` del registro.
    let objetivo: Double
    let objetivoTexto: String
    let montoInicial: Double
    /// Progreso real (inicial + movimientos): puede ser negativo.
    let ahorrado: Double
    let ahorradoTexto: String
    /// Ya viene con piso 0 y tope 100, 1 decimal.
    let porcentaje: Double
    let faltante: Double
    let faltanteTexto: String
    let fechaObjetivo: String?
    let fechaObjetivoTexto: String?
    let diasRestantes: Int?
    let apartadoMensual: Double?
    let apartadoMensualTexto: String?
    let estado: String
    let frase: String
    let completada: Bool
    let archivada: Bool
    /// La cuenta se devuelve como `cuenta_id` (la ida es
    /// `financial_account_id`).
    let cuentaId: Int?
    let cuentaNombre: String?
    let movimientos: [MetaMovimientoDto]

    enum CodingKeys: String, CodingKey {
        case id, nombre, porcentaje, faltante, estado, frase, completada, archivada, movimientos
        case objetivo
        case objetivoTexto = "objetivo_texto"
        case montoInicial = "monto_inicial"
        case ahorrado
        case ahorradoTexto = "ahorrado_texto"
        case faltanteTexto = "faltante_texto"
        case fechaObjetivo = "fecha_objetivo"
        case fechaObjetivoTexto = "fecha_objetivo_texto"
        case diasRestantes = "dias_restantes"
        case apartadoMensual = "apartado_mensual"
        case apartadoMensualTexto = "apartado_mensual_texto"
        case cuentaId = "cuenta_id"
        case cuentaNombre = "cuenta_nombre"
    }

    init(id: Int = 0, nombre: String = "", objetivo: Double = 0, objetivoTexto: String = "",
         montoInicial: Double = 0, ahorrado: Double = 0, ahorradoTexto: String = "",
         porcentaje: Double = 0, faltante: Double = 0, faltanteTexto: String = "",
         fechaObjetivo: String? = nil, fechaObjetivoTexto: String? = nil,
         diasRestantes: Int? = nil, apartadoMensual: Double? = nil,
         apartadoMensualTexto: String? = nil, estado: String = "", frase: String = "",
         completada: Bool = false, archivada: Bool = false,
         cuentaId: Int? = nil, cuentaNombre: String? = nil,
         movimientos: [MetaMovimientoDto] = []) {
        self.id = id
        self.nombre = nombre
        self.objetivo = objetivo
        self.objetivoTexto = objetivoTexto
        self.montoInicial = montoInicial
        self.ahorrado = ahorrado
        self.ahorradoTexto = ahorradoTexto
        self.porcentaje = porcentaje
        self.faltante = faltante
        self.faltanteTexto = faltanteTexto
        self.fechaObjetivo = fechaObjetivo
        self.fechaObjetivoTexto = fechaObjetivoTexto
        self.diasRestantes = diasRestantes
        self.apartadoMensual = apartadoMensual
        self.apartadoMensualTexto = apartadoMensualTexto
        self.estado = estado
        self.frase = frase
        self.completada = completada
        self.archivada = archivada
        self.cuentaId = cuentaId
        self.cuentaNombre = cuentaNombre
        self.movimientos = movimientos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
        objetivo = try c.decodeIfPresent(Double.self, forKey: .objetivo) ?? 0
        objetivoTexto = try c.decodeIfPresent(String.self, forKey: .objetivoTexto) ?? ""
        montoInicial = try c.decodeIfPresent(Double.self, forKey: .montoInicial) ?? 0
        ahorrado = try c.decodeIfPresent(Double.self, forKey: .ahorrado) ?? 0
        ahorradoTexto = try c.decodeIfPresent(String.self, forKey: .ahorradoTexto) ?? ""
        porcentaje = try c.decodeIfPresent(Double.self, forKey: .porcentaje) ?? 0
        faltante = try c.decodeIfPresent(Double.self, forKey: .faltante) ?? 0
        faltanteTexto = try c.decodeIfPresent(String.self, forKey: .faltanteTexto) ?? ""
        fechaObjetivo = try c.decodeIfPresent(String.self, forKey: .fechaObjetivo)
        fechaObjetivoTexto = try c.decodeIfPresent(String.self, forKey: .fechaObjetivoTexto)
        diasRestantes = try c.decodeIfPresent(Int.self, forKey: .diasRestantes)
        apartadoMensual = try c.decodeIfPresent(Double.self, forKey: .apartadoMensual)
        apartadoMensualTexto = try c.decodeIfPresent(String.self, forKey: .apartadoMensualTexto)
        estado = try c.decodeIfPresent(String.self, forKey: .estado) ?? ""
        frase = try c.decodeIfPresent(String.self, forKey: .frase) ?? ""
        completada = try c.decodeIfPresent(Bool.self, forKey: .completada) ?? false
        archivada = try c.decodeIfPresent(Bool.self, forKey: .archivada) ?? false
        cuentaId = try c.decodeIfPresent(Int.self, forKey: .cuentaId)
        cuentaNombre = try c.decodeIfPresent(String.self, forKey: .cuentaNombre)
        movimientos = try c.decodeIfPresent([MetaMovimientoDto].self, forKey: .movimientos) ?? []
    }
}

struct MetaMovimientoDto: Codable, Identifiable {
    let id: Int
    let fecha: String
    let fechaTexto: String
    /// Positivo = aportacion, negativo = retiro.
    let monto: Double
    let montoTexto: String
    let nota: String?

    enum CodingKeys: String, CodingKey {
        case id, fecha, monto, nota
        case fechaTexto = "fecha_texto"
        case montoTexto = "monto_texto"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha) ?? ""
        fechaTexto = try c.decodeIfPresent(String.self, forKey: .fechaTexto) ?? ""
        monto = try c.decodeIfPresent(Double.self, forKey: .monto) ?? 0
        montoTexto = try c.decodeIfPresent(String.self, forKey: .montoTexto) ?? ""
        nota = try c.decodeIfPresent(String.self, forKey: .nota)
    }
}

struct CuentaSimpleDto: Codable, Identifiable {
    let id: Int
    let nombre: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(Int.self, forKey: .id) ?? 0
        nombre = try c.decodeIfPresent(String.self, forKey: .nombre) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, nombre
    }
}

/// Respuesta de crear/editar/archivar/aportar una meta. Como en la
/// Android, el cliente la descarta y recarga el GET completo; se
/// decodifica solo para validar que el servidor respondio bien.
struct MetaRespuestaDto: Codable {
    let meta: MetaDto

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        meta = try c.decodeIfPresent(MetaDto.self, forKey: .meta) ?? MetaDto()
    }

    enum CodingKeys: String, CodingKey {
        case meta
    }
}
