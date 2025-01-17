USE [BD_MUNICIPALIDADMALARGUE]
GO

EXEC sp_sys_VentaEntradas_Entradas_F700_Cine 0,0,'12-1-2024','12-30-2024'


/****** Object:  StoredProcedure [dbo].[sp_sys_VentaEntradas_Entradas_F700_Cine]    Script Date: 11/12/2024 10:34:00 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_F700_Cine]
(
   @Id_Distribuidor INT,
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;


	
 --   DECLARE @Id_Evento INT=0
	--DECLARE @Id_Distribuidor INT=0
	--DECLARE @Fecha_Desde DATETIME='12-1-2024';
	--DECLARE @Fecha_Hasta DATETIME='12-6-2024';
 
	DECLARE @Calendario TABLE
	( 
		Periodo INT,
		Fecha DATE
	);

	DECLARE @Periodo INT;
	DECLARE @Fecha DATE=@Fecha_Desde;

	WHILE @Fecha<=@Fecha_Hasta
	BEGIN
		IF DAY(@Fecha) <=7 
			SET @Periodo=1;
		ELSE IF DAY(@Fecha)<=15 
			SET @Periodo=2;
		ELSE IF DAY(@Fecha)<=22
			SET @Periodo=3;
		ELSE 
			SET @Periodo=4;

		INSERT INTO @Calendario( Periodo, Fecha ) 
		VALUES( @Periodo, @Fecha);

		SET @FECHA=DATEADD(DAY,1,@FECHA);
	END;

	WITH Entradas as (
		SELECT		
				e.Id as Id_Entrada, 

				fu.Id as Id_Funcion_Ubicacion, 
				f.Id as Id_funcion, 
				ev.Id as Id_Evento, 
				t_fu.Id as Id_t_fu,
				t.Id as Id_Tarifa,

				u.Id as Id_Ubicacion,

				CASE WHEN e.Entrada_Anulada=1 AND e.ACTIVO=0 THEN 'DEVO' 
					 WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'BASE'
					ELSE 'BASE' END  AS Tipo_Funcion,

				CASE WHEN e.Entrada_Anulada=1 AND e.ACTIVO=0 THEN 'DEVO' 
					 WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'CORT'
					ELSE 'BASE' END  AS Tipo_Entrada

		FROM sys_VentaEntradas_Entradas e
		INNER join sys_VentaEntradas_Entradas_ItemCarrito eic on eic.Id_Entrada = e.Id

		INNER join sys_VentaEntradas_ItemCarrito ic on ic.Id=eic.Id_ItemCarrito 
		INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on fu.Id=ic.Id_FuncionUbicacion 
		INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
		INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id

		INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
		INNER JOIN sys_VentaEntradas_Lugares L ON L.Id=u.Id_Lugar
		INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine LI ON LI.Id_Ubicacion=u.Id
		INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa and ic.id_Tarifa=t.Id 
		WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta AND 
					( (ev.Id=@Id_Evento OR @Id_Evento<=0 OR  @Id_Evento is null) )
					AND NOT(e.CORTESIA=1 AND e.ACTIVO=1 )
		UNION
		SELECT		
				e.Id as Id_Entrada, 

				fu.Id as Id_Funcion_Ubicacion, 
				f.Id as Id_funcion, 
				ev.Id as Id_Evento, 
				t_fu.Id as Id_t_fu,
				t.Id as Id_Tarifa,

				u.Id as Id_Ubicacion,

				CASE WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'BASE'
					ELSE 'BASE' END  AS Tipo_Funcion,

				CASE WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'CORT'
					ELSE 'BASE' END  AS Tipo_Entrada

		FROM sys_VentaEntradas_Entradas e
		INNER join sys_VentaEntradas_Entradas_ItemCarrito eic on eic.Id_Entrada = e.Id

		INNER join sys_VentaEntradas_ItemCarrito ic on ic.Id=eic.Id_ItemCarrito 
		INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on fu.Id=ic.Id_FuncionUbicacion 
		INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
		INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id

		INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
		INNER JOIN sys_VentaEntradas_Lugares L ON L.Id=u.Id_Lugar
		INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine LI ON LI.Id_Ubicacion=u.Id
		INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa and ic.id_Tarifa=t.Id 
		WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta AND 
					( (ev.Id=@Id_Evento OR @Id_Evento<=0 OR  @Id_Evento is null) )
					AND NOT(e.CORTESIA=1 AND e.ACTIVO=1 )
					AND (e.Entrada_Anulada=1 AND e.Activo=0)
		UNION
		SELECT DISTINCT  
				e.Id as Id_Entrada, 

				fu.Id as Id_Funcion_Ubicacion, 
				f.Id as Id_funcion, 
				ev.Id as Id_Evento, 

				0 as Id_Precio,
				0 as Id_Tarifa,

				u.Id as Id_Ubicacion,

				CASE WHEN e.Entrada_Anulada=1 AND e.ACTIVO=0 THEN 'DEVO' 
					 WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'BASE'
					ELSE 'BASE' END  AS Tipo_Funcion,

				CASE WHEN e.Entrada_Anulada=1 AND e.ACTIVO=0 THEN 'DEVO' 
					 WHEN e.CORTESIA=1 AND e.ACTIVO=1 THEN 'CORT'
					ELSE 'BASE' END  AS Tipo_Entrada

		FROM sys_VentaEntradas_Entradas e
		INNER join sys_VentaEntradas_Entradas_ItemCarrito eic on eic.Id_Entrada = e.Id

		INNER join sys_VentaEntradas_ItemCarrito ic on ic.Id=eic.Id_ItemCarrito 
		INNER JOIN sys_VentaEntradas_FuncionUbicacion fu on fu.Id=ic.Id_FuncionUbicacion 
		INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
		INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 

		INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
		INNER JOIN sys_VentaEntradas_Lugares L ON L.Id=u.Id_Lugar
		INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine LI ON LI.Id_Ubicacion=u.Id
		INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
		WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta AND 
					( (ev.Id=@Id_Evento OR @Id_Evento<=0 OR  @Id_Evento is null) )
					AND (e.CORTESIA=1 AND e.ACTIVO=1)
		)

	,  Salas_Incaa AS(
		SELECT  cal.Periodo as Periodo_Fiscal, cal.Fecha as Fecha_Calendario,
				si.Id as Id_Sala , si.Codigo_Incaa as Codigo_Sala, si.Id_Ubicacion 
		FROM @Calendario as cal, sys_VentaEntradas_Ubicaciones_Salas_Cine AS si		
	)
	, Funciones AS(
		SELECT fu.Id as Id_fu, 
				f.Id as Id_f, f.Fecha as Fecha_f, 
				ev.Id as Id_ev, 
				t_fu.Id as Id_t_fu, 
				t_fu.Precio as Precio,
				u.Id as Id_u, 
				t.Id as Id_t,
				L.Id as Id_l, 
				LI.Id as Id_li, 
				evI.Id as Id_evI,
				t.[Es_Default] as [default]
		FROM sys_VentaEntradas_FuncionUbicacion fu 
		INNER JOIN sys_VentaEntradas_Funciones f on f.Id = fu.Id_Funcion
		INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id
		INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
		INNER JOIN sys_VentaEntradas_Lugares L ON L.Id=u.Id_Lugar
		INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine LI ON LI.Id_Ubicacion=u.Id
		INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
		INNER JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa 
		WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE,f.Fecha)<=@Fecha_Hasta AND 
				( (ev.Id=@Id_Evento OR @Id_Evento<=0 OR  @Id_Evento is null) OR
				  (evI.Id_Distribuidor=@Id_Distribuidor OR @Id_Distribuidor<=0 OR  evI.Id_Distribuidor is null))
	)
	, Numeracion_Funcion AS (
	SELECT DISTINCT f.fecha_f, ROW_NUMBER() OVER (PARTITION BY CONVERT(DATE, f.fecha_f) ORDER BY f.fecha_f) as nr
	from Funciones f
	GROUP BY f.fecha_f
	)

	--select * from Numeracion_Funcion

	,Funciones_De_Las_Salas AS
	(
			(
			SELECT s.Periodo_Fiscal, s.Codigo_Sala, s.Fecha_Calendario, f.Fecha_f as Fecha_Hora_Funcion,
					evI.Codigo_Incaa as Codigo_Pelicula,
					di.Codigo_Incaa as Codigo_Distribuidor,
					f.Precio,
					f.Id_fu, f.Id_f, f.Id_ev,  f.Id_t_fu,  f.Id_u,  f.Id_l, f.Id_li, f.Id_evI, f.Id_t,

					f.[default], 'BASE' AS Tipo_Funcion,

					f.Id_t_fu as Id_t_fu_pseudo,  f.Id_t as Id_t_pseudo
			FROM Salas_Incaa as s
			LEFT JOIN Funciones as f ON f.Id_u=s.Id_Ubicacion and s.Fecha_Calendario=CONVERT(DATE, f.Fecha_f)
			LEFT JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=f.Id_ev
			LEFT JOIN sys_VentaEntradas_Distribuidores_Cine dI ON dI.Id=evI.Id_Distribuidor
			)
		UNION
			(SELECT s.Periodo_Fiscal, s.Codigo_Sala, s.Fecha_Calendario, f.Fecha_f as Fecha_Hora_Funcion,
				evI.Codigo_Incaa as Codigo_Pelicula,
				di.Codigo_Incaa as Codigo_Distribuidor,
				f.Precio,

				f.Id_fu,  f.Id_f,  f.Id_ev,  f.Id_t_fu ,f.Id_u,  f.Id_l,  f.Id_li,  f.Id_evI, f.Id_t, 

				f.[default],'BASE' AS Tipo_Funcion,

				0 as Id_t_fu_pseudo, 0 as Id_t_pseudo
			FROM Salas_Incaa as s
			LEFT JOIN Funciones as f ON f.Id_u=s.Id_Ubicacion and s.Fecha_Calendario=CONVERT(DATE, f.Fecha_f)
			LEFT JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=f.Id_ev
			LEFT JOIN sys_VentaEntradas_Distribuidores_Cine dI ON dI.Id=evI.Id_Distribuidor
			WHERE f.[default]=1
		)
	)
	, Entradas_incaa AS
	(	SELECT 
				fs.Periodo_Fiscal, fs.Codigo_Sala, fs.Fecha_Calendario, fs.Fecha_Hora_Funcion,  fs.Codigo_Pelicula, fs.Codigo_Distribuidor,
				fs.Precio, 

				fs.Id_fu, fs.Id_f, fs.Id_ev, fs.Id_t_fu, fs.Id_u, fs.Id_t,
				e.Id_Entrada, 

				fs.Tipo_Funcion AS Tipo_Funcion_f,
				e.Tipo_Funcion as Tipo_Funcion_e, 
				e.Tipo_Entrada AS Tipo_Entrada,

				e.Id_t_fu AS e_Id_t_fu, 
				e.Id_Tarifa AS e_Id_t

		FROM Funciones_De_Las_Salas fs
		LEFT JOIN entradas e ON e.Id_Funcion_Ubicacion = fs.Id_fu
						AND e.Id_funcion = fs.Id_f
						AND e.Id_Evento = fs.Id_ev
						AND e.Id_Ubicacion = fs.Id_u
						AND e.Id_t_fu=fs.Id_t_fu_pseudo and e.Id_Tarifa=fs.Id_t_pseudo
						)
	,Resumen_Entradas_incaa AS (

		SELECT  r.Periodo_Fiscal,
				r.Fecha_Calendario,
				r.Fecha_Hora_Funcion,
				r.Codigo_Sala,
				r.Codigo_Pelicula,
				r.Codigo_Distribuidor,
				r.Precio,
				r.Id_fu,
				r.Id_f,
				r.Id_ev,
				r.Id_t_fu,
				r.Id_u,
				r.Id_t,
				r.Tipo_Funcion_f,
				r.Tipo_Funcion_e,
				r.Tipo_Entrada,

				r.e_Id_t_fu,
				r.e_Id_t,

				COUNT(r.Id_Entrada) as Cantidad
		FROM Entradas_incaa r
		Group by    r.Periodo_Fiscal,
					r.Fecha_Calendario,
					r.Fecha_Hora_Funcion,
					r.Codigo_Sala,
					r.Codigo_Pelicula,
					r.Codigo_Distribuidor,
					r.Precio,
					r.Id_fu,
					r.Id_f,
					r.Id_ev,
					r.Id_t_fu,
					r.Id_u,
					r.Id_t,
					r.Tipo_Funcion_f,
					r.Tipo_Funcion_e,
					r.Tipo_Entrada,
					r.e_Id_t_fu,
					r.e_Id_t
	)
	
	SELECT  
			rI.Periodo_Fiscal,
			rI.Codigo_Sala,
			rI.Fecha_Calendario,
			rI.Fecha_Hora_Funcion,
			rI.Codigo_Pelicula,

			case when ri.Tipo_Funcion_e='DEVO' THEN 'DEVO' ELSE ri.Tipo_Funcion_f END AS Tipo_Funcion, 

			rI.Codigo_Distribuidor,				

			ISNULL( CONVERT(VARCHAR(50), ( SELECT TOP 1 eI.Id_Entrada
											FROM Entradas_incaa eI 
											WHERE eI.Id_f =rI.Id_f 
													AND eI.Id_ev=rI.Id_ev 
													AND eI.Id_t_fu=rI.Id_t_fu
													AND eI.Id_t=rI.Id_t 
													AND eI.Id_u=rI.Id_u
													AND eI.Tipo_Entrada=rI.Tipo_Entrada
											ORDER BY eI.Id_Entrada DESC)) ,'')AS Numero_Primer_Boc ,

			1 AS Serie,

			ISNULL(rI.Precio/1.10,0.0) AS Precio_Basico,
			ISNULL( rI.Precio/1.10*10/100,0.0 )  AS Impuesto,
			ISNULL(rI.Cantidad, 0.0) AS Cantidad_Entradas,
			ISNULL(rI.Precio/1.10*10/100*rI.Cantidad,0.0 ) AS Total_Impuesto,

			rI.Id_fu AS Id_FuncionUbicacion,
			rI.Id_f AS Id_Funcion,
			rI.Id_ev AS Id_Evento,
			rI.Id_t_fu AS Id_Tarifa_FuncionUbicacion,
			rI.Id_u AS Id_Ubicacion,
			rI.Id_t AS Id_Tarifa,
			CASE WHEN rI.Tipo_Entrada='BASE' OR rI.Tipo_Entrada='DEVO' OR rI.Tipo_Entrada IS NULL THEN ISNULL(rI.Precio,0.0 ) 
				    ELSE 0.0  END AS Precio_Venta,
			rI.Tipo_Entrada,			
			nf.nr as Numero_Funcion,
			(SELECT  CASE WHEN rI.Tipo_Entrada='CORT' THEN 'Z'
				WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%MAY%' OR UPPER(SUBSTRING(t.Descripcion,1,3)) like '%GEN%' THEN 'R' 
                WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%MEN%' THEN 'S' 
			    WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%JUB%' THEN 'Q' 
				END ) Letra_Tarifa
	FROM Resumen_Entradas_incaa rI
	LEFT JOIN sys_Tarifas t ON t.Id=rI.Id_t
	LEFT JOIN Numeracion_Funcion nf ON nf.Fecha_f=rI.Fecha_Hora_Funcion
	ORDER BY rI.Periodo_Fiscal ASC,
				rI.Fecha_Calendario ASC,
				rI.Fecha_Hora_Funcion ASC,
				Tipo_Funcion ASC,
				rI.Codigo_Distribuidor ASC,
				rI.Precio DESC

				
END