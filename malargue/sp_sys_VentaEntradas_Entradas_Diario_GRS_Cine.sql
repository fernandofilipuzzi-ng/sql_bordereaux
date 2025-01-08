USE [BD_MUNICIPALIDADMALARGUE]
GO
/****** Object:  StoredProcedure [dbo].[sp_sys_VentaEntradas_Entradas_Diario_GRS_Cine]    Script Date: 8/1/2025 15:43:39 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_Diario_GRS_Cine]
(
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;


		
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
				@Id_Evento=@Id_Evento, 
				@Fecha_Desde=@Fecha_Desde, @Fecha_Hasta=@Fecha_Hasta;
				
	WITH EntradasPrecio AS(
		SELECT e.*, tfu.Precio as PrecioEntradaFinal
		FROM @Entradas e
		INNER JOIN sys_Tarifas_U_FuncionUbicacion tfu ON tfu.Id=e.Id_Tarifa_FuncionUbicacion AND tfu.Id_Tarifa=e.Id_Tarifa AND tfu.Id_FuncionUbicacion=e.Id_FuncionUbicacion
		WHERE e.Tipo_Entrada <> 'CORT'AND e.Tipo_Entrada <> 'DEVO'
	)
	, Resumen AS(
		select  e.Fecha_Hora_Funcion, e.Fecha_Calendario, e.Codigo_Pelicula, e.Id_Evento, 
				e.PrecioEntradaFinal as Precio_Venta,
				SUM(e.Cantidad_Entradas) as Cantidad_Entradas
		From EntradasPrecio e
		GROUP BY  e.Fecha_Hora_Funcion, e.Codigo_Pelicula, e.Fecha_Calendario,
					e.Codigo_Pelicula, e.Id_Evento, e.PrecioEntradaFinal
	)
	
	SELECT r.*, p.Descripcion, p.Formato
	FROM Resumen r
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine p ON p.Id_Evento=r.Id_Evento
	ORDER BY r.Codigo_Pelicula ASC, r.Fecha_Hora_Funcion ASC, r.Precio_Venta DESC

END