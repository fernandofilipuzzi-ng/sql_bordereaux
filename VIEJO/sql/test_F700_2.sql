

--TEST DE CANTIDAD DE ENTRADAS

--USE BD_MUNICIPALIDADORAN
--USE BD_MINACLAVERO
USE BD_CINEMALVINAS
--USE BD_MUNICIPALIDADMALARGUE
--USE BD_CINEOPENPLAZA
--USE BD_MUNICIPALIDADMALARGUE

GO

DECLARE @Desde DATETIME='11-1-2024';
DECLARE @Hasta DATETIME='12-30-2024';

SELECT CONVERT(DATE,f.Fecha), Cantidad=count(*), Recaudacion=SUM(CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  ELSE  fu.Precio END )				
	FROM sys_VentaEntradas_Entradas e
	INNER join sys_VentaEntradas_Entradas_ItemCarrito eic ON eic.Id_Entrada = e.Id
	INNER join sys_VentaEntradas_ItemCarrito ic ON ic.Id=eic.Id_ItemCarrito 
	INNER JOIN sys_VentaEntradas_FuncionUbicacion fu ON fu.Id=ic.Id_FuncionUbicacion 
	INNER JOIN sys_VentaEntradas_Funciones f ON f.Id = fu.Id_Funcion
	INNER JOIN sys_VentaEntradas_Eventos ev ON f.Id_Evento=ev.Id 
	INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion 
	INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine LI ON LI.Id_Ubicacion=u.Id
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	INNER JOIN sys_VentaEntradas_Distribuidores_Cine dI ON dI.Id=evI.Id_Distribuidor
	LEFT JOIN sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id
	INNER JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa and ic.id_Tarifa=t.Id 
	WHERE CONVERT(DATE, f.Fecha)>=@Desde AND CONVERT(DATE, f.Fecha)<=@Hasta -- AND ( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa<=0 OR  @Codigo_Incaa IS NULL ) 
GROUP BY CONVERT(DATE,f.Fecha)
ORDER BY CONVERT(DATE,f.Fecha) ASC



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
EXEC sp_sys_VentaEntradas_Entradas_F700_Cine 0,0,@Desde,@Hasta



select e.Fecha_Calendario , Cantidad =sum(case when e.Tipo_Entrada='DEVOLUCION' THEN 0 ELSE e.Cantidad_Entradas END) ,
		Recaudacion=sum(case when e.Tipo_Entrada='DEVOLUCION' THEN 0 ELSE e.Precio_Venta* e.Cantidad_Entradas*1.00 END)  
FROM @Entradas e group by  e.Fecha_Calendario HAVING sum(case when e.Tipo_Entrada='DEVOLUCION' THEN 0 ELSE e.Cantidad_Entradas END)>0


select * from @Entradas ;


EXEC sp_sys_VentaEntradas_Entradas_F700_Cine 0,0,'11-1-2024','11-30-2024'
