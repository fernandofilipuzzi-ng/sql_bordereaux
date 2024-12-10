

--USE BD_MUNICIPALIDADORAN
--USE BD_MINACLAVERO
--USE BD_CINEMALVINAS
--USE BD_MUNICIPALIDADMALARGUE
--USE BD_CINEOPENPLAZA
---USE BD_MUNICIPALIDADMALARGUE

--CREATE PROCEDURE [dbo].[sp_sys_VentaEntradas_Entradas_F700_Cine_2]
--(
--   @Id_Distribuidor INT,
--   @Id_Evento INT,
--   @Fecha_Desde DATE,
--   @Fecha_Hasta DATE
--)
--AS
--BEGIN

--	SET NOCOUNT ON;

	DECLARE @Id_Evento INT=0
	--DECLARE @Desde DATETIME='11-1-2024';
	--DECLARE @Hasta DATETIME='11-30-2024';

	DECLARE @Fecha_Desde DATETIME='11-6-2024';
	DECLARE @Fecha_Hasta DATETIME='11-6-2024';

	--CUANDO hace LA MISMA pelicula en VARIOS EVENTOS
	DECLARE @Codigo_Incaa NVARCHAR(50)='64240248';--'63240017';
	--SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	--FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	--WHERE c.Id_Evento=@Id_Evento;


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

		-- quita el guion bajo (cuando tienen salas con el mismo codigo)
		INSERT INTO @Calendario( Periodo, Fecha, Codigo_Sala  ) 
		SELECT DISTINCT @Periodo, @Fecha, REPLACE(sc.Codigo_Incaa,'_','') FROM sys_VentaEntradas_Ubicaciones_Salas_Cine sc

		SET @FECHA=DATEADD(DAY,1,@FECHA);
	END;

	--SELECT * FROM @Calendario

	--FUNCIONES-EVENTOS-TIPO_TARIFA DISPONIBLES (contempla rotular la que es base para asignar las entradas CORT)


	-- me trae todas las tariafas con su funcion/evento

	DECLARE @Funciones TABLE(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Codigo_Pelicula NVARCHAR(50),
		FechaHora_Funcion DATETIME,
		Precio_Venta NUMERIC(18,3), --el precio de tarifa -que  puede ser general o venta 
		Precio_Sin_Impuesto NUMERIC(18,3), --se calcula del precio venta /1.10
		Codigo_Distribuidor NVARCHAR(50),
		Codigo_Sala NVARCHAR(50),
		Tipo_Tarifa NVARCHAR(7) DEFAULT '', --GENERAL (el precio principal) o nada (son los otros)	,
		Es_General BIT, -- lo uso luego para saber si es base
		Serie NVARCHAR(50)
	)

	INSERT INTO @Funciones (Codigo_Pelicula, FechaHora_Funcion, Precio_Venta, Codigo_Distribuidor, Codigo_Sala, Es_General, Serie)
	SELECT DISTINCT evI.Codigo_Incaa AS Codigo_Pelicula, 
					f.Fecha AS FechaHora_Funcion, 
					Precio_Venta=CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  --tarifas
										ELSE  fu.Precio END, --tarifa unica
					dI.Codigo_Incaa AS Codigo_Distribuidor,
					REPLACE(scI.Codigo_Incaa,'_','') AS Codigo_Sala,
					t.Es_Default ,
					(--SELECT  CASE WHEN rI.Tipo_Entrada='CORT' THEN 'Z'
					CASE WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%MAY%' OR UPPER(SUBSTRING(t.Descripcion,1,3)) like '%GEN%' THEN 'R' 
						WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%MEN%' THEN 'S' 
						WHEN UPPER(SUBSTRING(t.Descripcion,1,3)) like '%JUB%' THEN 'Q' 
						END ) Serie
	FROM sys_VentaEntradas_Funciones f 
	INNER JOIN sys_VentaEntradas_Eventos ev on f.Id_Evento=ev.Id 
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	INNER JOIN sys_VentaEntradas_Distribuidores_Cine dI ON dI.Id=evI.Id_Distribuidor
	INNER JOIN sys_VentaEntradas_FuncionUbicacion fu ON fu.Id_Funcion=f.Id
	INNER JOIN sys_VentaEntradas_Ubicaciones u ON u.Id=fu.Id_Ubicacion
	INNER JOIN sys_VentaEntradas_Ubicaciones_Salas_Cine scI ON scI.Id_Ubicacion=u.Id 
	LEFT JOIN  sys_Tarifas_U_FuncionUbicacion t_fu ON t_fu.Id_FuncionUbicacion=fu.Id 
	LEFT JOIN sys_Tarifas t ON t.Id = t_fu.Id_Tarifa 
	WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta AND 
			( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa<=0 OR  @Codigo_Incaa IS NULL )
			--
			--controla que tenga tarifa
			AND(  CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  ELSE  fu.Precio END IS NOT NULL AND CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  ELSE  fu.Precio END >0 )
			--
	ORDER BY FechaHora_Funcion ASC, Codigo_Pelicula ASC,  Precio_Venta DESC

	--SELECT * FROM @Funciones



	-- DETERMINAR QUE TARIFA ES GENERAL POR EL MAYOR VALOR O SI FUE MARCADA
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
		DECLARE @Id_Funcion_General INT=NULL;--es importante inicializar en null!

		--reviso si hay alguna tarifa marcada como general

		SELECT TOP 1 @Id_Funcion_General=f.Id 
		FROM @Funciones f
		WHERE Codigo_Pelicula=@Codigo_Pelicula  AND Codigo_Pelicula=@Codigo_Pelicula AND Codigo_Sala=@Codigo_Sala AND FechaHora_Funcion=@FechaHora_Funcion 
				AND f.Es_General =1;
		
		IF(@Id_Funcion_General IS NULL)
		BEGIN
			-- sino busco con la mayor tarifa		
			SELECT TOP 1  @Id_Funcion_General=f.Id 
			FROM @Funciones f
			WHERE f.Codigo_Distribuidor=@Codigo_Distribuidor AND f.Codigo_Pelicula=@Codigo_Pelicula	AND f.Codigo_Sala=@Codigo_Sala AND f.FechaHora_Funcion=@FechaHora_Funcion 
			ORDER BY f.Precio_Venta DESC
		END

		UPDATE @Funciones SET Tipo_Tarifa='GENERAL' WHERE Id=@Id_Funcion_General;
		
		FETCH NEXT FROM Cursor_Funcion INTO @Codigo_Distribuidor, @Codigo_Pelicula, @Codigo_Sala, @FechaHora_Funcion;
	END;

	CLOSE Cursor_Funcion;
	DEALLOCATE Cursor_Funcion;

	UPDATE @Funciones SET Precio_Sin_Impuesto=Precio_Venta/1.10

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
				REPLACE(LI.Codigo_Incaa,'_','') AS Codigo_Sala,
				dI.Codigo_Incaa AS Codigo_Distribuidor,
				--
				f.Fecha AS FechaHora_Funcion,
				e.Entrada_Anulada, e.Activo, e.Cortesia  AS Es_Cortesia,
				--
				Precio_Venta=CASE WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  --tarifas
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
	INNER JOIN sys_Tarifas t ON t.Id=t_fu.Id_Tarifa and ic.id_Tarifa=t.Id 
	WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta AND ( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa<=0 OR  @Codigo_Incaa IS NULL ) 
		--	AND e.Id in (11493,11495)


	--SELECT * 
	--FROM @Funciones f
	--INNER JOIN @Entradas e ON f.Codigo_Distribuidor=e.Codigo_Distribuidor AND f.Codigo_Pelicula=e.Codigo_Pelicula AND f.Codigo_Sala=e.Codigo_Sala AND f.FechaHora_Funcion=e.FechaHora_Funcion
	--WHERE e.Id IN (19515, 19516,19532,19533) AND f.Tipo_Tarifa like 'GENERAL' 



	--SELECT * FROM @Entradas e -- WHERE e.FechaHora_Funcion='2024-10-02 22:00:00.000' and Es_Cortesia=1

	-- depurando las entradas precios y tipo de entrada o 

	DECLARE @Entrada_Incaa TABLE
	(
		Id_Entrada INT,
		Codigo_Pelicula NVARCHAR(50),
		Codigo_Sala NVARCHAR(50),
		Codigo_Distribuidor NVARCHAR(50),
		Fecha_Funcion DATETIME,
		Precio_Tarifa NUMERIC(18,3), --
		Tipo_Transaccion NVARCHAR(50), --NORMAL (INCLUYE LAS VENDIDAS mas LAS DEVO) O DEVOLUCION (estas se vuelven a insertar -pero como devo)
		Tipo_Distribucion NVARCHAR(50), --VENTA (se toma el precio_lista) O CORTESIA(se toma el precio base del general para el informe, pero se informa cero)
		--
		Precio_Base NUMERIC(18,3),--precio sin el impuesto - 10%
		Precio_Base_Final NUMERIC(18,3), --puede ser cero si es cortesia
		--
		Orden INT
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

		DECLARE @Precio_Base NUMERIC(18,3);
		DECLARE @Precio_Base_Final NUMERIC(18,3); 
		DECLARE @Precio_Tarifa NUMERIC(18,3);
		DECLARE @Precio_CORT NUMERIC(18,3);
	
		DECLARE @Tipo_Distribucion NVARCHAR(50)=NULL;
		DECLARE @Tipo_Transaccion NVARCHAR(50)=NULL;
		DECLARE @MULT INT=1;

		DECLARE @Orden INT;
	

		SELECT TOP 1 @Es_Anulada=e.Es_Anulada, @ES_Activo=e.ES_Activo, @Es_Cortesia=e.Es_Cortesia, @Precio_Tarifa=e.Precio_Venta
		FROM @Entradas e WHERE e.Id=@Id_Entrada;

		--CORTESIA 
		IF @Es_Anulada=0 AND @Es_Cortesia =1 
		BEGIN
			SET @Tipo_Distribucion='CORTESIA'; --o normal
			SET @Tipo_Transaccion='NULL';--no tiene transaccion

			--le pone el precio general
			SELECT @Precio_Tarifa=f.Precio_Venta 
			FROM @Funciones f
			INNER JOIN @Entradas e ON f.Codigo_Distribuidor=e.Codigo_Distribuidor AND f.Codigo_Pelicula=e.Codigo_Pelicula AND f.Codigo_Sala=e.Codigo_Sala AND f.FechaHora_Funcion=e.FechaHora_Funcion
			WHERE e.Id=@Id_Entrada AND f.Tipo_Tarifa like 'GENERAL';

			SET @MULT=0;
		END
		
		--NORMALES
		ELSE 
		BEGIN
			SET @Tipo_Distribucion='VENTA'; --o cortesia
			SET @Tipo_Transaccion='NORMAL'-- o devolución 
		END

		SET @Precio_Base=@Precio_Tarifa/1.10 ;
		SET @Precio_Base_Final= @Precio_Base*@MULT;

		INSERT INTO @Entrada_Incaa(Id_Entrada, Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala,  Fecha_Funcion,  Precio_Tarifa, Precio_Base,  Precio_Base_Final, Tipo_Distribucion, Tipo_Transaccion)
		SELECT e.Id, e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.FechaHora_Funcion,  @Precio_Tarifa, @Precio_Base, @Precio_Base_Final, @Tipo_Distribucion, @Tipo_Transaccion 
		FROM @Entradas e 
		WHERE e.Id=@Id_Entrada
		
		--DEVO - la duplica pero como DEVO
		IF @Es_Anulada=1
		BEGIN

			SET @Tipo_Distribucion='VENTA'; 
			SET @Tipo_Transaccion='DEVOLUCION';

			INSERT INTO @Entrada_Incaa(Id_Entrada, Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala,  Fecha_Funcion,  
						Precio_Tarifa, Tipo_Distribucion, Tipo_Transaccion, Precio_Base, Precio_Base_Final)
			SELECT e.Id, e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.FechaHora_Funcion, 
						@Precio_Tarifa, @Tipo_Distribucion, @Tipo_Transaccion, @Precio_Base,@Precio_Base_Final
			FROM @Entradas e 
			WHERE e.Id=@Id_Entrada
		END

		FETCH NEXT FROM Cursor_Entrada INTO @Id_Entrada;
	END

	CLOSE Cursor_Entrada;
	DEALLOCATE Cursor_Entrada;

	--e.FechaHora_Funcion= and Es_Cortesia=1
	--SELECT * FROM @Entrada_Incaa e--  where e.Fecha_Funcion='2024-10-30 20:00:00.000' ;

	--select * from @Entrada_Incaa e --where e.Fecha_Funcion='2024-12-01 20:15:00.000'


	--Resume las entradas - cantidades por función y etc.

	DECLARE @Resumen_Entrada TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Codigo_Distribuidor NVARCHAR(50),
		Codigo_Pelicula NVARCHAR(50),
		Codigo_Sala NVARCHAR(50),
		Fecha_Funcion DATETIME,
		Precio_Tarifa DECIMAL(18,3),
		Cantidad_Entrada INT,
		Tipo_Transaccion NVARCHAR(50),
		Tipo_Distribucion NVARCHAR(50),
		--
		Precio_Base Numeric(18,3),
		Precio_Base_Final DECIMAL(18,3),
		--
		Numero_Primer_BOC INT,
		Total_Impuesto Numeric(18,3)

	)

	INSERT INTO @Resumen_Entrada(Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala, Fecha_Funcion, Precio_Tarifa, Precio_Base, Precio_Base_Final, Cantidad_Entrada, e.Tipo_Distribucion, Tipo_Transaccion)
	SELECT e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion,e.Precio_Tarifa, e.Precio_Base, e.Precio_Base_Final,  COUNT(*) AS Cantidad_Entrada, e.Tipo_Distribucion, e.Tipo_Transaccion 			
	FROM @Entrada_Incaa e
	GROUP BY e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Base_Final,  e.Precio_Tarifa, e.Tipo_Distribucion, e.Tipo_Transaccion , e.Precio_Base
	ORDER BY e.Fecha_Funcion, e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Precio_Tarifa DESC


	--SELECT * FROM @Resumen_Entrada

	-- ACTUALIZANDO EL RESUMEN DE ENTRADAS CON SU PRIMER BOC 

	DECLARE CURSOR_REntrada CURSOR FOR SELECT re.ID FROM @Resumen_Entrada re
	DECLARE @Id_REntrada INT;

	OPEN CURSOR_REntrada;

	FETCH NEXT FROM CURSOR_REntrada INTO @Id_REntrada ;

	WHILE @@FETCH_STATUS=0
	BEGIN
		DECLARE @Primer_BOC INT=NULL;

		-- busco el primer id de cada grupo
		SELECT TOP 1 @Primer_BOC=ei.Id_Entrada
		FROM @Entrada_Incaa ei
		INNER JOIN @Resumen_Entrada re ON re.Codigo_Sala=ei.Codigo_Sala AND re.Codigo_Pelicula=ei.Codigo_Pelicula AND		
				re.Codigo_Distribuidor=ei.Codigo_Distribuidor AND ei.Fecha_Funcion=re.Fecha_Funcion AND 
				ei.Precio_Tarifa=re.Precio_Tarifa AND ei.Tipo_Transaccion=re.Tipo_Transaccion
		WHERE re.Id=@Id_REntrada
		ORDER BY ei.Id_Entrada ASC 
	   	
		UPDATE @Resumen_Entrada SET Numero_Primer_BOC=@Primer_BOC, 
									Total_Impuesto=Precio_Base*0.1*Cantidad_Entrada
		WHERE Id=@Id_REntrada
	   
		FETCH NEXT FROM CURSOR_REntrada INTO @Id_Rentrada ;
	END

	CLOSE CURSOR_REntrada;
	DEALLOCATE CURSOR_REntrada; 
								
								
	-- JUNTANDO TODO -       CALENDARIO | Datos de la función |  entradas
	DECLARE @Bordereaux TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Periodo INT,
		Codigo_Sala NVARCHAR(50), 
		--
		Fecha_Calendario DATE, 
		FechaHora_Funcion DATETIME, 
		--
		Numero_Primer_Boc INT,
		--
		Codigo_Pelicula NVARCHAR(50),
		Distribucion NVARCHAR(50),
		Codigo_Distribuidor NVARCHAR(50),
		Precio_Base NUMERIC(18,3),--precio sin el impuesto 1/1.1
		Impuesto  NUMERIC(18,3),--10 % del precio de venta
		Cantidad_Entradas INT,
		--
		Total_Impuesto NUMERIC(18,3),
		--
		Precio_Venta NUMERIC(18,3),
		Tipo_Transaccion NVARCHAR(50),
		Tipo_Distribucion NVARCHAR(50),
		--
		Serie_Letra NVARCHAR(50),
		Orden_Serie INT
	);


	INSERT INTO @Bordereaux (Periodo, Codigo_Sala, Fecha_Calendario, FechaHora_Funcion, Numero_Primer_Boc, Codigo_Pelicula, Distribucion, Codigo_Distribuidor, Precio_Base, Impuesto, Cantidad_Entradas, Total_Impuesto, Precio_Venta, Tipo_Transaccion, Tipo_Distribucion, Serie_Letra, Orden_Serie)
	SELECT c.Periodo, c.Codigo_Sala,
			--
			c.Fecha AS 'Fecha_Calendario',
			f.FechaHora_Funcion AS 'FechaHora_Funcion',
			--
			re.Numero_Primer_Boc,
			--
			f.Codigo_Pelicula, 
			Distribucion=CASE WHEN re.Tipo_Transaccion='NORMAL' OR re.Tipo_Distribucion='CORTESIA' THEN 'BASE'
							  WHEN re.Tipo_Transaccion='DEVOLUCION' THEN 'DEVO'
							  ELSE 'BASE' END,
			f.Codigo_Distribuidor,
			--
			Precio_Base=CASE WHEN re.Tipo_Distribucion LIKE 'CORTESIA' THEN re.Precio_Base_Final ELSE f.Precio_Sin_Impuesto  END,
			Impuesto=f.Precio_Sin_Impuesto*0.1,
			--ISNULL(f.Precio_Sin_Impuesto, 0.00) AS Precio_Base,------------ACA!!!.- PLEASE!
			--
			ISNULL(re.Cantidad_Entrada,0) AS Cantidad_Entradas,
			--
			ISNULL(re.Total_Impuesto,0.00) AS Total_Impuesto,
			--
			--Precio_Venta = case WHEN re.Tipo_Transaccion NOT LIKE 'DEVOLUCION'  THEN f.Precio_Venta ELSE 0.0 END ,
			ISNULL(f.Precio_Venta ,0.00),
			--
			re.Tipo_Transaccion,
			re.Tipo_Distribucion,
			--
			--f.Serie
			Letra_Tarifa=CASE WHEN re.Tipo_Distribucion='CORTESIA' THEN 'Z'
							  ELSE f.Serie END,
			--
			Orden_Serie=CASE WHEN re.Tipo_Transaccion='DEVOLUSION' THEN 0 ELSE 1 END
			--
	FROM @Calendario c
	LEFT JOIN @Funciones f ON f.Codigo_Sala=c.Codigo_Sala AND CONVERT(DATE,f.FechaHora_Funcion)=c.Fecha
	LEFT JOIN @Resumen_Entrada re ON re.Codigo_Distribuidor=f.Codigo_Distribuidor AND
									re.Codigo_Pelicula=f.Codigo_Pelicula AND
									re.Codigo_Sala=f.Codigo_Sala AND
									re.Fecha_Funcion=f.FechaHora_Funcion AND 
									re.Precio_Tarifa=f.Precio_Venta
	ORDER BY c.Periodo ASC, c.Fecha ASC, c.Codigo_Sala ASC, f.FechaHora_Funcion ASC, f.Codigo_Pelicula ASC, f.Codigo_Distribuidor ASC, f.Precio_Venta DESC, Letra_Tarifa DESC, re.Tipo_Transaccion DESC

	--select * from @Calendario c
	--SELECT * FROM @Bordereaux

	--ADAPTANDO A LA SALIDA ANTIGUA. - Primer bordereaux

	SELECT  
			b.Periodo AS Periodo_Fiscal,
			b.Codigo_Sala AS Codigo_Sala,
			b.Fecha_Calendario Fecha_Calendario,
			b.FechaHora_Funcion Fecha_Hora_Funcion,
			b.Codigo_Pelicula AS Codigo_Pelicula,
			ISNULL(b.Distribucion,'BASE') Tipo_Funcion,
			--
			b.Codigo_Distribuidor,
			b.Numero_Primer_Boc,
			b.Orden_Serie AS Serie,
			--
			b.Precio_Base AS Precio_Basico,
			b.Impuesto AS Impuesto,
			b.Cantidad_Entradas, 
			ISNULL( b.Total_Impuesto,0.00) AS Total_Impuesto,
			--
			0 AS Id_FuncionUbicacion,
			0 AS Id_Funcion,
			0 AS Id_Evento,
			0 AS Id_Tarifa_FuncionUbicacion,
			0 AS Id_Ubicacion,
			0 AS Id_Tarifa,
			--
			b.Precio_Venta,
			--
			Tipo_Entrada=CASE WHEN b.Tipo_Distribucion='CORTESIA' THEN 'CORTESIA'
							  WHEN b.Tipo_Transaccion='DEVOLUCION' THEN 'DEVOLUCION'
							  ELSE 'NORMAL' END,
			--ISNULL(b.Tipo_Transaccion,'NORMAL') AS Tipo_Entrada,
			0 As Numero_Funcion,
			--
			b.Serie_Letra AS Letra_Tarifa
			--
			--ISNULL(b.Serie,'Z') AS Letra_Tarifa
			--
	FROM @Bordereaux b
	--WHERE b.FechaHora_Funcion = '2024-10-02 22:00:00.000'
	ORDER BY Periodo_Fiscal ASC, Codigo_Sala ASC, Fecha_Calendario ASC, Fecha_Hora_Funcion ASC, Codigo_Pelicula ASC, Codigo_Distribuidor ASC, Precio_Basico DESC, b.Serie_Letra DESC, b.Orden_Serie DESC

	SELECT  b.Fecha_Calendario,SUM(b.Cantidad_Entradas) ---SUM(CASE WHEN b.Tipo_Transaccion='DEVOLUCION' THEN 0 ELSE b.Cantidad_Entradas END ) 
	FROM @Bordereaux b
	WHERE b.Tipo_Transaccion noT LIKE 'DEVOLUCION' AND b.Tipo_Distribucion noT LIKE 'CORTESIA'
	GROUP BY b.Fecha_Calendario



	--SELECT +84+1+125-5+4+34-2+1

--END