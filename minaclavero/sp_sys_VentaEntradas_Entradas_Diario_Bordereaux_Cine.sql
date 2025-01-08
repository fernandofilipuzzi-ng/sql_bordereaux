USE [BD_MINACLAVERO]
GO
/****** Object:  StoredProcedure [dbo].[sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine]    Script Date: 8/1/2025 15:50:46 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine]
(
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;
	   	
	--declare @Id_Evento INT=7;
	--DECLARE @Fecha_Desde DATETIME='10-1-2024';
	--DECLARE @Fecha_Hasta DATETIME='10-4-2024';


	DECLARE @Codigo_Incaa INT;
	SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa from sys_VentaEntradas_Eventos_Peliculas_Cine c where c.Id_Evento=@Id_Evento;
	
	
		
	DECLARE @Entradas TABLE
	(
		Periodo_Fiscal INT,
		Codigo_Sala VARCHAR(100),
		Fecha_Calendario DATE,
		Fecha_Hora_Funcion DATETIME,
		Codigo_Pelicula VARCHAR(100),
		Tipo_Funcion VARCHAR(100),
		Codigo_Distribuidor VARCHAR(100),
		--
		Numero_Primer_Boc VARCHAR(100),
		Serie INT, 
		--
		Precio_Basico Decimal,
		Impuesto DECIMAL,
		Cantidad_Entradas INT,
		Total_Impuesto DECIMAL,
		--
		Id_FuncionUbicacion INT,
		Id_Funcion INT,
		Id_Evento INT,
		Id_Tarifa_FuncionUbicacion INT,
		Id_Ubicacion INT,
		Id_Tarifa INT,
		--
		Precio_Venta DECIMAL,
		Tipo_Entrada VARCHAR(100),
		Numero_Funcion INT,
		Letra_Tarifa VARCHAR(100)
	);
	INSERT INTO @Entradas
	EXEC sp_sys_VentaEntradas_Entradas_F700_Cine @Id_Distribuidor=0, 
				@Id_Evento=@Id_Evento, 
				@Fecha_Desde=@Fecha_Desde, @Fecha_Hasta=@Fecha_Hasta;

	DECLARE @Tiene_Argentores BIT='true';
	DECLARE @Porc_Argentores NUMERIC(18,2)=0.0;
	DECLARE @Porc_SAGAI NUMERIC(18,2)=0;
	SELECT TOP 1 @Tiene_Argentores=evI.Argentores,  
				 @Porc_Argentores=evI.Porcentaje_Argentores,           
				 @Porc_SAGAI=evI.Porcentaje_SAGAI           
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	WHERE evI.Codigo_Incaa=@Codigo_Incaa;--ev.Id=@Id_Evento;

	--SELECT * FROM @Entradas
	   

	WITH Detalle_Total AS
	(
		SELECT e.Fecha_Calendario,e.Id_Tarifa
				,SUM( CASE WHEN e.Tipo_Entrada='DEVO' THEN -e.Cantidad_Entradas ELSE e.Cantidad_Entradas END ) AS Cantidad_Entradas
				,SUM( CASE WHEN e.Tipo_Entrada='DEVO' THEN -e.Precio_Venta*e.Cantidad_Entradas ELSE e.Precio_Venta*e.Cantidad_Entradas  END) AS Recaudacion_Entradas
		FROM @Entradas e
		GROUP BY  e.Fecha_Calendario,  e.Id_Tarifa
	)
	
	, Detalle_Total_Ponderado AS(
		SELECT dt.*,
					( SELECT TOP 1 tfu.Precio 
					  FROM sys_Tarifas t 
					  INNER JOIN sys_Tarifas_U_FuncionUbicacion tfu ON t.Id=tfu.Id_Tarifa 
					  INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on fu.Id=tfu.Id_FuncionUbicacion
					  INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
					  INNER JOIN sys_VentaEntradas_Eventos ev on ev.Id=f.Id_Evento
				      WHERE t.Id=dt.Id_Tarifa AND ev.Id=@Id_Evento AND f.Fecha>=@Fecha_Desde
					  ORDER BY tfu.Id DESC) AS Precio_Venta
		FROM Detalle_Total dt
	)
	
	, Detalle_Total_Numerado AS (
		SELECT dt.*, ROW_NUMBER() OVER (PARTITION BY dt.Fecha_Calendario
										ORDER BY  dt.Fecha_Calendario ASC, dt.Precio_Venta DESC) AS nr
		FROM Detalle_Total_Ponderado dt
	)

	--select * from Detalle_Total_Numerado
	
	
	, Detalle_Totales2 AS (
		SELECT dtn.Fecha_Calendario as Fecha,

				SUM(CASE WHEN dtn.nr=1 THEN dtn.Recaudacion_Entradas ELSE 0.0 END) AS Recaudacion_Entradas1,
				SUM(CASE WHEN dtn.nr=1 THEN dtn.Cantidad_Entradas ELSE 0 END) AS Cantidad_Entradas1,
	
				SUM(CASE WHEN dtn.nr=2 THEN dtn.Recaudacion_Entradas ELSE 0.0 END) AS Recaudacion_Entradas2,
				SUM(CASE WHEN dtn.nr=2 THEN dtn.Cantidad_Entradas ELSE 0 END) AS Cantidad_Entradas2,

				SUM(CASE WHEN dtn.nr=3 THEN dtn.Recaudacion_Entradas ELSE 0.0 END) AS Recaudacion_Entradas3,
				SUM(CASE WHEN dtn.nr=3 THEN dtn.Cantidad_Entradas ELSE 0 END) AS Cantidad_Entradas3,

				SUM(CASE WHEN dtn.nr=4 THEN dtn.Recaudacion_Entradas ELSE 0.0 END) AS Recaudacion_Entradas4,
				SUM(CASE WHEN dtn.nr=4 THEN dtn.Cantidad_Entradas ELSE 0 END) AS Cantidad_Entradas4,

				SUM(CASE WHEN dtn.nr=5 THEN dtn.Recaudacion_Entradas ELSE 0.0 END) AS Recaudacion_Entradas5,
				SUM(CASE WHEN dtn.nr=5 THEN dtn.Cantidad_Entradas ELSE 0 END) AS Cantidad_Entradas5,

				SUM(dtn.Cantidad_Entradas) AS Cantidad_Total_Entradas,

				SUM(dtn.Recaudacion_Entradas ) AS Monto_Diario

		FROM Detalle_Total_Numerado dtn
		GROUP BY dtn.Fecha_Calendario
	)


	
	, Detalle_Totales3 AS (
		SELECT dt.*,
				ISNULL(dt.Monto_Diario/1.31*@Porc_Argentores/100,0.0) AS Argentores, 
				ISNULL(dt.Monto_Diario/1.31*@Porc_SAGAI/100,0.0) as Sagai
		FROM Detalle_Totales2 dt
	)
	SELECT dt.*
	FROM Detalle_Totales3 dt

END
