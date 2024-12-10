--ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine_2]
--(
--   @Id_Evento INT,
--   @Fecha_Desde DATE,
--   @Fecha_Hasta DATE
--)
--AS
--BEGIN

    DECLARE @Id_Evento INT=0;
	DECLARE @Fecha_Desde DATETIME='11-5-2024';
	DECLARE @Fecha_Hasta DATETIME='11-6-2024';

	SET NOCOUNT ON;

	DECLARE @Codigo_Incaa NVARCHAR(50)='64240248';--;'63240017';
	--SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	--FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	--WHERE c.Id_Evento=@Id_Evento;

	SELECT TOP 1 @Id_Evento=ev.ID
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine c ON c.Id_Evento=ev.Id
	WHERE c.Codigo_Incaa=@Codigo_Incaa;


	DECLARE @Entradas TABLE
	(
		Periodo_Fiscal INT,
		Codigo_Sala VARCHAR(100),
		Fecha_Calendario DATE,
		Fecha_Hora_Funcion DATETIME,
		Codigo_Pelicula VARCHAR(100),
		Tipo_Funcion VARCHAR(100),
		Codigo_Distribuidor VARCHAR(100),

		Numero_Primer_Boc VARCHAR(100),
		Serie INT, 

		Precio_Basico Decimal,
		Impuesto DECIMAL,
		Cantidad_Entradas INT,
		Total_Impuesto DECIMAL,

		Id_FuncionUbicacion INT,
		Id_Funcion INT,
		Id_Evento INT,
		Id_Tarifa_FuncionUbicacion INT,
		Id_Ubicacion INT,
		Id_Tarifa INT,

		Precio_Venta DECIMAL,
		Tipo_Entrada VARCHAR(100),
		Numero_Funcion INT,
		Letra_Tarifa VARCHAR(100)
	);
	INSERT INTO @Entradas
	EXEC sp_sys_VentaEntradas_Entradas_F700_Cine_2 @Id_Distribuidor=0, @Id_Evento=@Id_Evento, @Fecha_Desde=@Fecha_Desde, @Fecha_Hasta=@Fecha_Hasta;
		
    -- TABLA DOBLE entrada
	DECLARE @Diario TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Fecha DATE,
		Id_Tarifa INT,
		Cantidad_Entradas INT,
		Precio_Venta NUMERIC(18,3),
		Recaudacion NUMERIC(18,3)
	)
	INSERT INTO @Diario(Fecha)
	SELECT e.Fecha_Calendario 
	FROM @Entradas e 
	GROUP BY e.Fecha_Calendario 
	ORDER BY e.Fecha_Calendario ASC;


	-- CUADRO TARIFARIO EN ESTE PERIODO
	DECLARE @Tarifas TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Precio_Venta NUMERIC(18,3)
	)
	INSERT INTO @Tarifas SELECT e.Precio_Venta FROM @Entradas e WHERE e.Tipo_Entrada NOT LIKE 'CORTESIA' AND e.Tipo_Entrada NOT LIKE 'DEVOLUCION' 
	GROUP BY e.Precio_Venta


	/*
	1000     5   4/5/2024
	1000     5   4/5/2024
	5000     5   5/5/2024
	 

	           1000         50000
	4/5/202    10           0 
	5/5/2024   0			 5        
	 */


	
	DECLARE @Tarifas_Fecha TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Precio_Venta NUMERIC(18,3)
	)
	INSERT INTO @Tarifas_Fecha
	SELECT e.Fecha_Calendario, .Precio_Venta
	FROM @Entradas e 
	WHERE e.Tipo_Entrada NOT LIKE 'CORTESIA' AND e.Tipo_Entrada NOT LIKE 'DEVOLUCION' 
	GROUP BY e.Fecha_Calendario, .Precio_Venta
	   
	



	-- TODAS LAS FECHAS CON SUS TARIFAS
	DECLARE @Resumen_Fechas_Tarifas TABLE(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Fecha DATE,
		Precio_Venta NUMERIC(18,3),
		Cantidad_Entradas INT,
		Recaudacion NUMERIC(18,3)
	);
	
	INSERT INTO @Resumen_Fechas_Tarifas (Fecha, Precio_Venta, Cantidad_Entradas, Recaudacion)
	SELECT e.Fecha_Calendario, 
			e.Precio_Venta, 
			Cantidad_Entradas=SUM(e.Cantidad_Entradas), 
			Recaudacion=SUM(  e.Precio_Venta*e.Cantidad_Entradas) 
	FROM @Entradas e 
	WHERE e.Tipo_Entrada NOT LIKE 'CORTESIA' AND e.Tipo_Entrada NOT LIKE 'DEVOLUCION' 
	GROUP BY e.Fecha_Calendario, e.Precio_Venta
	ORDER BY e.Fecha_Calendario ASC, e.Precio_Venta DESC

	--NORMALIZO EN TODO EL PERIODO - MITAD IZQUIERDA TARIFAS, MITAD DERECHA ENTRADAS AGRUPADAS 
	DECLARE Tarifa_Resumen_Entradas
	(
		Precio_Venta.
		Id_Resumen
	)

	


	--HAGO UN BARRIDO Z

	DECLARE @Fecha_Resumen DATE; 
	DECLARE CURSOR_Fechas CURSOR FOR 
	SELECT r.Id 
	FROM  @Tarifas_Del_Periodo tp 
	LEFT JOIN @Resumen_Fechas_Tarifas r ON tp.Precio_Venta=tp.Precio_Venta
	GROUP BY r.Fecha 
	ORDER BY r.Fecha ASC;

	OPEN CURSOR_Fechas;
	FETCH NEXT FROM CURSOR_Fechas INTO @Fecha_Resumen;

	WHILE @@FETCH_STATUS=0
	BEGIN

			
		DECLARE CURSOR_Tarifa CURSOR FOR SELECT 

		SELECT * FROM @Resumen_Fechas_Tarifas r WHERE r.Fecha

		FETCH NEXT FROM CURSOR_Fechas INTO @Id_Resumen;
	END

--END
