
SET NOCOUNT ON;

DECLARE @Id_Evento INT;
DECLARE @Desde DATETIME='10-1-2024';
DECLARE @Hasta DATETIME='10-4-2024';

--CUANDO hace LA MISMA pelicula en VARIOS EVENTOS
DECLARE @Codigo_Incaa INT;
SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
WHERE c.Id_Evento=@Id_Evento;


-- CREAR CALENDARIO: PERIODO (depende de FECHA) y FECHA para sacar el dia  - CODIGO_SALA
-- filtrar todas las evento-funciones-tarifas o precios: CODIGO_DISTRIBUIDOR/CODIGO_PELICULA/CODIGO_SALA/FECHA_HORA/Precio_Venta
-- filtrar todas las entradas 
-- unir esos tres
        -- LAS NORMALES - serían los precios disponibles si se especifican aunque no hay entradas.
		         --(por eso no puedo considerar una tarifa con cero)
        -- *CORTESIA - si no hay no se especifica -
		-- *DEVOLUCIONES se tienen se toman como BASE y luego se vuelven a insertar con DEVO
		-- (se suman a las entradas vendidas  y se especifican aparte)
		-- si no hay devoluciones no se especifican


-- CALENDARIO

DECLARE @Calendario TABLE
( 
	Periodo INT,
	Fecha DATE,
	Codigo_Sala NVARCHAR(50)
);

DECLARE @Periodo INT;
DECLARE @Fecha DATE=@Desde;

WHILE @Fecha<=@Hasta
BEGIN
	IF DAY(@Fecha) <=7 
		SET @Periodo=1;
	ELSE IF DAY(@Fecha)<=15 
		SET @Periodo=2;
	ELSE IF DAY(@Fecha)<=22
		SET @Periodo=3;
	ELSE 
		SET @Periodo=4;

	-- quita el guion bajo (cuando tienen salas con el mismo codigo)
	INSERT INTO @Calendario( Periodo, Fecha, Codigo_Sala  ) 
	SELECT DISTINCT @Periodo, @Fecha, REPLACE(sc.Codigo_Incaa,'_','') FROM sys_VentaEntradas_Ubicaciones_Salas_Cine sc

	SET @FECHA=DATEADD(DAY,1,@FECHA);
END;

--SELECT * FROM @Calendario

--FUNCIONES-EVENTOS-TIPO_TARIFA DISPONIBLES (contempla rotular la que es base para asignar las entradas CORT)

DECLARE @Funciones TABLE(
	Id INT PRIMARY KEY IDENTITY(1,1),
	Codigo_Pelicula NVARCHAR(50),
	FechaHora_Funcion DATETIME,
	Precio_Venta NUMERIC(18,3), -- puede ser general o venta 
	Codigo_Distribuidor NVARCHAR(50),
	Codigo_Sala NVARCHAR(50),
	Tipo_Tarifa NVARCHAR(7) DEFAULT '', --GENERAL (el precio principal) o nada (son los otros)	,
	Es_General BIT -- lo uso luego para saber si es base
)

INSERT INTO @Funciones (Codigo_Pelicula, FechaHora_Funcion, Precio_Venta, Codigo_Distribuidor, Codigo_Sala, Es_General)
SELECT DISTINCT evI.Codigo_Incaa AS Codigo_Pelicula, 
				f.Fecha AS FechaHora_Funcion, 
				Precio_Venta=CASE 
						WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  --tarifas
						ELSE  fu.Precio END, --tarifa unica
				dI.Codigo_Incaa AS Codigo_Distribuidor,
				REPLACE(scI.Codigo_Incaa,'_','') AS Codigo_Sala,
				t.Es_Default 
FROM sys_VentaEntradas_Funciones f 
INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 
INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
INNER JOIN sys_VentaEntradas_Distribuidores_Cine dI ON dI.Id=evI.Id_Distribuidor
INNER JOIN sys_VentaEntradas_FuncionUbicacion fu ON fu.Id_Funcion=f.Id
INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine scI ON scI.Id_Ubicacion=u.Id 
LEFT JOIN  sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id 
LEFT JOIN sys_Tarifas t ON t.Id = t_fu.Id_Tarifa
WHERE CONVERT(DATE, f.Fecha)>=@Desde AND CONVERT(DATE, f.Fecha)<=@Hasta AND 
		( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa<=0 OR  @Codigo_Incaa IS NULL )
ORDER BY Codigo_Pelicula ASC, FechaHora_Funcion ASC, Precio_Venta DESC

-- agrupo cada función 
DECLARE Cursor_Funcion CURSOR FOR 
SELECT Codigo_Distribuidor, f.Codigo_Pelicula, f.Codigo_Sala, f.FechaHora_Funcion
FROM @Funciones f 
GROUP BY  Codigo_Distribuidor, f.Codigo_Pelicula, f.Codigo_Sala, f.FechaHora_Funcion

DECLARE @Codigo_Pelicula NVARCHAR(50); 
DECLARE @Codigo_Distribuidor NVARCHAR(50);
DECLARE @Codigo_Sala NVARCHAR(50);
DECLARE @FechaHora_Funcion DATETIME ;

OPEN Cursor_Funcion;

FETCH NEXT FROM Cursor_Funcion INTO @Codigo_Distribuidor, @Codigo_Pelicula, @Codigo_Sala,@FechaHora_Funcion;

WHILE @@FETCH_STATUS=0
BEGIN

	--reviso si hay alguna tarifa marcada como general
	DECLARE @Id_Funcion INT;
	SELECT TOP 1 @Id_Funcion=f.Id FROM @Funciones f
	WHERE Codigo_Pelicula=@Codigo_Pelicula  AND Codigo_Pelicula=@Codigo_Pelicula AND Codigo_Sala=@Codigo_Sala AND FechaHora_Funcion=@FechaHora_Funcion 
				AND f.Es_General =1;

	IF(@Id_Funcion IS NOT NULL)
		UPDATE @Funciones SET Tipo_Tarifa='GENERAL' WHERE Id=@Id_Funcion;
	ELSE
	    --busco el arancel mayor del grupo 
		UPDATE @Funciones SET Tipo_Tarifa='GENERAL'
		WHERE Id IN ( SELECT TOP 1  f.Id FROM @Funciones f
						WHERE f.Codigo_Distribuidor=@Codigo_Distribuidor AND f.Codigo_Pelicula=@Codigo_Pelicula	AND f.Codigo_Sala=@Codigo_Sala AND f.FechaHora_Funcion=@FechaHora_Funcion 
						ORDER BY f.Precio_Venta DESC );
				
	FETCH NEXT FROM Cursor_Funcion INTO @Codigo_Distribuidor, @Codigo_Pelicula,@Codigo_Sala,@FechaHora_Funcion;
END;

CLOSE Cursor_Funcion;
DEALLOCATE Cursor_Funcion;

--SELECT * FROM  @Funciones


--CONSULTA DE ENTRADAS EN EL PERIODO


----CONSULTA DE ENTRADAS 

DECLARE @Entradas TABLE(
  Id INT,
  Codigo_Pelicula NVARCHAR(50),
  Codigo_Sala NVARCHAR(50),
  Codigo_Distribuidor NVARCHAR(50),
  FechaHora_Funcion DATETIME,
  Es_Anulada BIT,
  ES_Activo BIT,
  Es_Cortesia BIT,
  Precio_Venta NUMERIC(18,3))

INSERT INTO @Entradas(Id, Codigo_Pelicula, Codigo_Sala, Codigo_Distribuidor, FechaHora_Funcion, Es_Anulada, Es_Activo, Es_Cortesia, Precio_Venta)
SELECT e.Id AS Id_Entrada, 
			--
			evI.Codigo_Incaa AS Codigo_Pelicula,  
			LI.Codigo_Incaa AS Codigo_Sala,
			dI.Codigo_Incaa AS Codigo_Distribuidor,
			--
			f.Fecha AS FechaHora_Funcion,
			e.Entrada_Anulada, e.Activo, e.Cortesia  AS Es_Cortesia,
			--
			Precio_Venta=CASE 
						WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  --tarifas
						ELSE  fu.Precio END --tarifa unica
			--
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
LEFT JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa and ic.id_Tarifa=t.Id 
WHERE CONVERT(DATE, f.Fecha)>=@Desde AND CONVERT(DATE, f.Fecha)<=@Hasta AND 
		( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa<=0 OR  @Codigo_Incaa IS NULL ) 

--SELECT * FROM @Entradas

-- depurando las entradas precios y tipo de entrada o 

DECLARE @Entrada_Incaa TABLE
(
	Codigo_Pelicula NVARCHAR(50),
	Codigo_Sala NVARCHAR(50),
	Codigo_Distribuidor NVARCHAR(50),
	Fecha_Funcion DATETIME,
	Precio_Final NUMERIC(18,3), --puede ser cero si es cortesia
	Precio_Tarifa NUMERIC(18,3), --
	Tipo_Transaccion NVARCHAR(50), --NORMAL (INCLUYE LAS VENDIDAS incluidas las devo) O DEVOLUCION (se reinsertar  las devo)
	Tipo_Distribucion NVARCHAR(50), --VENTA (se toma el precio_lista) O CORTESIA(se toma el precio base)
	--
	Precio_Base NUMERIC(18,3)
)

DECLARE Cursor_Entrada CURSOR FOR SELECT e.Id FROM @Entradas e;

OPEN Cursor_Entrada;

DECLARE @Id_Entrada INT;
FETCH NEXT FROM Cursor_Entrada INTO @Id_Entrada;

WHILE @@FETCH_STATUS=0
BEGIN	

	DECLARE @Es_Anulada BIT;
	DECLARE @ES_Activo BIT;
	DECLARE @Es_Cortesia BIT;

	DECLARE @Precio_Final NUMERIC(18,2);
	DECLARE @Precio_Tarifa NUMERIC(18,2);
	DECLARE @Precio_CORT NUMERIC(18,2);
	
	DECLARE @Tipo_Distribucion NVARCHAR(50)=NULL;
	DECLARE @Tipo_Transaccion NVARCHAR(50)=NULL;
	

	SELECT TOP 1 @Es_Anulada=e.Es_Anulada, @ES_Activo=e.ES_Activo, @Es_Cortesia=e.Es_Cortesia, @Precio_Final=e.Precio_Venta, @Precio_Tarifa=e.Precio_Venta
	FROM @Entradas e WHERE e.Id=@Id_Entrada;


	--CORTESIA 
	IF @Es_Anulada=0 AND @Es_Cortesia =1 
	BEGIN
		SET @Precio_Final=0;
		SET @Tipo_Distribucion='CORTESIA'; 
		SET @Tipo_Transaccion='NULL';

		SELECT @Precio_Tarifa=f.Precio_Venta 
				FROM @Entradas e
		INNER JOIN @Funciones f ON f.Codigo_Distribuidor=e.Codigo_Distribuidor AND f.Codigo_Pelicula=e.Codigo_Pelicula 
										AND f.Codigo_Sala=e.Codigo_Sala AND f.FechaHora_Funcion=e.FechaHora_Funcion
		WHERE e.Id=@Id_Entrada AND Tipo_Tarifa like 'GENERAL'
	END
		
	--NORMALES
	ELSE 
	BEGIN
		SET @Tipo_Distribucion='NORMAL'; 
		SET @Tipo_Transaccion='VENTA'
	END
	
	--DEVO
	IF @Es_Anulada=1 AND @ES_Activo=1
	BEGIN
		SET @Tipo_Distribucion='VENTA'; 
		SET @Tipo_Transaccion='DEVOLUCION';
	END

	INSERT INTO @Entrada_Incaa(Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala,  Fecha_Funcion,  Precio_Final, Precio_Tarifa, Tipo_Distribucion, Tipo_Transaccion)
	SELECT  e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.FechaHora_Funcion, @Precio_Final, @Precio_Tarifa, @Tipo_Distribucion, @Tipo_Transaccion
	FROM @Entradas e 
	WHERE e.Id=@Id_Entrada

	FETCH NEXT FROM Cursor_Entrada INTO @Id_Entrada;
END

CLOSE Cursor_Entrada;
DEALLOCATE Cursor_Entrada;


--SELECT * FROM @Entrada_Incaa;

--JUNTANDO TODO - REUNE CALENDARIO - FUNCIONES Y  ENTRADAS

--SELECT * FROM @Funciones
--SELECT * FROM @Entradas

--DECLARE @Resumen TABLE (
--	Codigo_Distribuidor NVARCHAR(50),
--	Codigo_Pelicula NVARCHAR(50),
--	Codigo_Sala NVARCHAR(50),
--	Fecha_Funcion DATETIME,
	
--);


--INSERT INTO @Resumen(Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion,e.Precio_Tarifa,e.Precio_Final)
--SELECT e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Tarifa, e.Precio_Final, COUNT(*) AS Cantidad_Entradas
--FROM @Entrada_Incaa e
--GROUP BY e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Tarifa, e.Precio_Final


--SELECT e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Tarifa, e.Precio_Final, COUNT(*) AS Cantidad_Entradas
--FROM @Entrada_Incaa e
--GROUP BY e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Tarifa, e.Precio_Final


UPDATE @Entrada_Incaa SET Precio_Base = Precio_Final/1.10


DECLARE @Resumen_Entrada TABLE
(
	Codigo_Distribuidor NVARCHAR(50),
	Codigo_Pelicula NVARCHAR(50),
	Codigo_Sala NVARCHAR(50),
	Fecha_Funcion DATETIME,
	Precio_Final DECIMAL(18,3),
	Cantidad_Entrada INT,
	Tipo_Transaccion NVARCHAR(50),
	Precio_Base Numeric(18,3)
)

INSERT INTO @Resumen_Entrada(Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala, Fecha_Funcion, Precio_Final, Tipo_Transaccion, Precio_Base, Cantidad_Entrada)
SELECT e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Final, e.Tipo_Distribucion, 
				E.Precio_Base,
				COUNT(*) AS Cantidad_Entrada
FROM @Entrada_Incaa e
GROUP BY e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Final, e.Tipo_Distribucion,E.Precio_Base

SELECT c.Periodo, c.Codigo_Sala, CONVERT(DATE,e.Fecha_Funcion) AS 'Fecha Funcion', CONVERT(TIME,f.FechaHora_Funcion) AS 'Hora función',
		f.Codigo_Pelicula, 
		Distribucion=CASE WHEN e.Tipo_Transaccion='NORMAL' THEN 'BASE'
						  WHEN e.Tipo_Transaccion='DEVOLUCION' THEN 'DEVO'
						  ELSE '' END,
		f.Codigo_Distribuidor,
		e.Precio_Base,
		e.Cantidad_Entrada
FROM @Calendario c
LEFT JOIN @Funciones f ON f.Codigo_Sala=c.Codigo_Sala AND CONVERT(DATE,f.FechaHora_Funcion)=c.Fecha
LEFT JOIN @Resumen_Entrada e ON e.Codigo_Distribuidor=f.Codigo_Distribuidor AND
								e.Codigo_Pelicula=f.Codigo_Pelicula AND
								e.Codigo_Sala=f.Codigo_Sala AND
								e.Fecha_Funcion=f.FechaHora_Funcion AND 
								e.Precio_Final=f.Precio_Venta
								
								




