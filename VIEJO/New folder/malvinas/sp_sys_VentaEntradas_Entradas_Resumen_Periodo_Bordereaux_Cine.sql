USE [BD_CINEMALVINAS]
GO
/****** Object:  StoredProcedure [dbo].[sp_sys_VentaEntradas_Entradas_Resumen_Periodo_Bordereaux_Cine]    Script Date: 11/12/2024 09:51:59 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_Resumen_Periodo_Bordereaux_Cine]
(
   @Id_Evento INT,
   @Desde DATE,
   @Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;


	
	
	 --DECLARE @Id_Evento INT=21;
  --   DECLARE @Desde DATE='7-1-2024';
  --   DECLARE @Hasta DATE='7-29-2024';

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
	EXEC sp_sys_VentaEntradas_Entradas_F700_Cine @Id_Distribuidor=0, 
				@Id_Evento=0, @Fecha_Desde=@Desde, @Fecha_Hasta=@Hasta;
	

	WITH Entradas_Filtradas AS
	(
		SELECT e.* 
		FROM @Entradas e
		INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine p ON p.Id_Evento=e.Id_Evento
		WHERE p.Codigo_Incaa = (SELECT TOP 1 pc.Codigo_Incaa FROM sys_VentaEntradas_Eventos_Peliculas_Cine pc WHERE pc.Id_Evento=@Id_Evento)
	)
	, Resumen_Por_Tarifa AS(
		SELECT  e.Id_Tarifa, 
				SUM( CASE WHEN e.Tipo_Entrada='DEVO' THEN -e.Precio_Venta*e.Cantidad_Entradas ELSE e.Precio_Venta*e.Cantidad_Entradas  END) AS Recaudacion_Venta,
				SUM( CASE WHEN e.Tipo_Entrada='DEVO' THEN -e.Cantidad_Entradas ELSE e.Cantidad_Entradas END ) AS Cantidad_Entradas
		FROM @Entradas e
		WHERE e.Tipo_Entrada <> 'CORT'AND e.Tipo_Entrada <> 'DEVO'
		GROUP BY  e.Id_Tarifa
	)

	--SELECT * FROM Resumen_Por_Tarifa

	, Resumen_Ordenado AS(
		SELECT rt.* , (SELECT TOP 1 (CASE WHEN tfu.Id IS NULL OR tfu.Id=0  THEN fu.Precio ELSE tfu.Precio END) AS Precio
					  FROM sys_VentaEntradas_Eventos ev  
					  INNER JOIN sys_VentaEntradas_Funciones f on f.Id_Evento=ev.Id
					  INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on  fu.Id_Funcion=f.Id
					  LEFT JOIN sys_Tarifas_U_FuncionUbicacion tfu ON tfu.Id_FuncionUbicacion=fu.Id
					  LEFT JOIN sys_Tarifas t ON t.Id=tfu.Id_Tarifa
					  --FROM sys_Tarifas t 
					  --INNER JOIN sys_Tarifas_U_FuncionUbicacion tfu ON t.Id=tfu.Id_Tarifa 
					  --INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on fu.Id=tfu.Id_FuncionUbicacion
					  --INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
					  --INNER JOIN sys_VentaEntradas_Eventos ev on ev.Id=f.Id_Evento
				      WHERE  ev.Id=@Id_Evento AND f.Fecha>=@Desde
					  ORDER BY tfu.Id DESC) AS Precio_Venta
		FROM Resumen_Por_Tarifa rt	
	)
	--SELECT * FROM Resumen_Ordenado 

	, Resumen_Enumerado AS (
		SELECT 'A' AS Grupo, rt.* , ROW_NUMBER() OVER (PARTITION BY 'A' ORDER BY rt.Precio_Venta DESC) as nd
		FROM Resumen_Ordenado rt		
	) 
	

	, Resumen_Final AS(
	SELECT TOP 1 
	        1 AS Linea,
			SUM(CASE WHEN re.nd=1 THEN re.Precio_Venta  ELSE 0.0 END) AS Col1,
			SUM(CASE WHEN re.nd=2 THEN re.Precio_Venta  ELSE 0.0 END) AS Col2,		
			SUM(CASE WHEN re.nd=3 THEN re.Precio_Venta  ELSE 0.0 END) AS Col3,
			SUM(CASE WHEN re.nd=4 THEN re.Precio_Venta  ELSE 0.0 END) AS Col4,
			SUM(CASE WHEN re.nd=5 THEN re.Precio_Venta  ELSE 0.0 END) AS Col5
	FROM Resumen_Enumerado re
	GROUP BY re.Grupo
	UNION
	SELECT TOP 1 
			2 AS Linea,
			SUM(CASE WHEN re.nd=1 THEN re.Precio_Venta/1.21  ELSE 0.0 END) AS Col1,
			SUM(CASE WHEN re.nd=2 THEN re.Precio_Venta/1.21  ELSE 0.0 END) AS Col2,		
			SUM(CASE WHEN re.nd=3 THEN re.Precio_Venta/1.21  ELSE 0.0 END) AS Col3,
			SUM(CASE WHEN re.nd=4 THEN re.Precio_Venta/1.21  ELSE 0.0 END) AS Col4,
			SUM(CASE WHEN re.nd=5 THEN re.Precio_Venta/1.21  ELSE 0.0 END) AS Col5
	FROM Resumen_Enumerado re
	GROUP BY re.Grupo
	UNION
	SELECT TOP 1 
			3 AS Linea,
			SUM(CASE WHEN re.nd=1 THEN re.Recaudacion_Venta/1.21  ELSE 0.0 END) AS Col1,
			SUM(CASE WHEN re.nd=2 THEN re.Recaudacion_Venta/1.21  ELSE 0.0 END) AS Col2,		
			SUM(CASE WHEN re.nd=3 THEN re.Recaudacion_Venta/1.21  ELSE 0.0 END) AS Col3,
			SUM(CASE WHEN re.nd=4 THEN re.Recaudacion_Venta/1.21  ELSE 0.0 END) AS Col4,
			SUM(CASE WHEN re.nd=5 THEN re.Recaudacion_Venta/1.21  ELSE 0.0 END) AS Col5
	FROM Resumen_Enumerado re
	GROUP BY re.Grupo
	)
	SELECT * FROM Resumen_Final rf ORDER BY rf.Linea  ASC

END