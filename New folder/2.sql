
USE BD_CINEMALVINAS;

GO

CREATE OR ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine_2]
(
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN

	--EXEC sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine_2 1079, '11-1-2024','11-6-2024'

    DECLARE @Id_Evento INT=0;
	DECLARE @Fecha_Desde DATETIME='12-1-2024';
	DECLARE @Fecha_Hasta DATETIME='12-6-2024';

	SET NOCOUNT ON;

	DECLARE @Codigo_Incaa NVARCHAR(50)='64240243'--=NULL;--'64240248';--'63240017';
	--SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	--FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	--WHERE c.Id_Evento=@Id_Evento;

	SELECT TOP 1 @Id_Evento=ev.ID
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine c ON c.Id_Evento=ev.Id
	WHERE c.Codigo_Incaa=@Codigo_Incaa;


	-- PARAMETROS GENERALES PARA ESTE EVENTO

	DECLARE @Tiene_Argentores BIT='true';
	DECLARE @Porc_Argentores NUMERIC(18,2)=0.0;
	DECLARE @Porc_SAGAI NUMERIC(18,2)=0;
	SELECT TOP 1 @Tiene_Argentores=evI.Argentores,  
				 @Porc_Argentores=evI.Porcentaje_Argentores,           
				 @Porc_SAGAI=evI.Porcentaje_SAGAI           
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	WHERE ev.Id=@Id_Evento;

	-- ENTRADAS F700

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

	SELECT * FROM @Entradas

	DECLARE @Entradas_Bordereaux TABLE
	(
		Id INT,
		Fecha DATE,
		Precio NUMERIC(18,3),
		Cantidad INT
	);
	INSERT INTO @Entradas_Bordereaux( Fecha, Precio, Cantidad)
	SELECT e.Fecha_Calendario, 
				e.Precio_Venta,
				Cantidad_Entradas=CASE WHEN e.Tipo_Entrada LIKE 'DEVOLUCION' THEN -e.Cantidad_Entradas ELSE e.Cantidad_Entradas END
	FROM @Entradas e
	WHERE e.Tipo_Entrada NOT LIKE 'CORTESIA' 

	SELECT * FROM @Entradas_Bordereaux 

	-- CALENDARIO - CADA UNO DE LOS DIAS INFORMADOS

	DECLARE @Calendario TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Fecha DATE
	)
	INSERT INTO @Calendario(Fecha)
	SELECT e.Fecha_Calendario  FROM @Entradas e  GROUP BY e.Fecha_Calendario  ORDER BY e.Fecha_Calendario ASC;
	
	-- CUADRO DE PRECIOS EN ESTE PERIODO - DE TODO EL PERIODO LOS "DIFERENTES VALORES" DE MAYOR A MENOR

	DECLARE @Precios TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Precio_Venta NUMERIC(18,3)
	)
	INSERT INTO @Precios SELECT e.Precio FROM @Entradas_Bordereaux e  GROUP BY e.Precio ORDER BY e.Precio DESC


	-- TABLA RESUMEN QUE SE INFORMA - la logica es usar la id de la fecha y la id de los precios como si fuera (fila, columna)
	/* OBJETIVO!

	DATOS
	1000     5   4/5/2024
	1000     5   4/5/2024
	5000     5   5/5/2024
	 

	SALIDA:

	           1000         50000
	4/5/202    10           0 
	5/5/2024   0			 5       
	
	tengo que MEZCLAR  las dos
	4/5/202 1 10
	4/5/202 2 0
	4/5/202 1 10
	 */

	 DECLARE @Resumen TABLE 
	 (
		Id INT PRIMARY KEY IDENTITY(1,1),
		Id_Fecha INT,
		Id_Tarifa INT,
		Recaudacion NUMERIC(18,3),
		Cantidad_Entradas INT
	 );

	 INSERT INTO @Resumen( Id_Fecha, Id_Tarifa, Recaudacion, Cantidad_Entradas )
	 SELECT tXd.Id_Fecha, TxD.Id_Tarifa, 
				Recaudacion=SUM( txD.Precio_Venta*e.Cantidad  ),
				Cantidad_Entradas=SUM( e.Cantidad )
	 FROM  (SELECT  c.Id AS Id_Fecha, t.Id as Id_Tarifa, c.Fecha, t.Precio_Venta FROM @Precios t, @Calendario c ) tXd
			LEFT JOIN @Entradas_Bordereaux e ON e.Fecha=tXd.Fecha AND tXd.Precio_Venta=e.Precio
	 GROUP BY  tXd.Id_Fecha, TxD.Id_Tarifa
	 ORDER BY  tXd.Id_Fecha ASC, TxD.Id_Tarifa DESC

	 DECLARE @Detalle TABLE 
	 (
		Fecha DATE,
		Recaudacion_Entradas1 NUMERIC(18,3),
		Cantidad_Entradas1 INT,
		Recaudacion_Entradas2 NUMERIC(18,3),
		Cantidad_Entradas2 INT,
		Recaudacion_Entradas3 NUMERIC(18,3),
		Cantidad_Entradas3 INT,
		Recaudacion_Entradas4 NUMERIC(18,3),
		Cantidad_Entradas4 INT,
		Recaudacion_Entradas5 NUMERIC(18,3),
		Cantidad_Entradas5 INT,
		--
		Cantidad_Total_Entradas INT,
		Monto_Diario NUMERIC(18,3),
		--
		Argentores NUMERIC(18,3),
		Sagai NUMERIC(18,3)
	 )

	 INSERT INTO @Detalle (Fecha, Recaudacion_Entradas1, Cantidad_Entradas1, Recaudacion_Entradas2, Cantidad_Entradas2, Recaudacion_Entradas3, Cantidad_Entradas3, Recaudacion_Entradas4, Cantidad_Entradas4, Recaudacion_Entradas5, Cantidad_Entradas5, Cantidad_Total_Entradas, Monto_Diario, Argentores, Sagai)
	 SELECT c.Fecha,
			--d
			Recaudacion_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Cantidad_Entradas ELSE 0 END ),
			--
			Recaudacion_Entradas_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Cantidad_Entradas ELSE 0 END ),
			--
			Recaudacion_Entradas_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Cantidad_Entradas ELSE 0 END ),
			--
			Recaudacion_Entradas_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Cantidad_Entradas ELSE 0 END ),
			--
			Recaudacion_Entradas_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Cantidad_Entradas ELSE 0 END ),
			--
			Cantidad_Total_Entradas=SUM(r.Cantidad_Entradas),
			Monto_Diario=SUM(r.Recaudacion),
			--
			Argentores=0.0,
			Sagai=0
	 FROM @Resumen r
	 INNER JOIN @Calendario c ON c.Id=r.Id_Fecha
	 GROUP BY c.Fecha;

	 SELECT * FROM @Detalle

END