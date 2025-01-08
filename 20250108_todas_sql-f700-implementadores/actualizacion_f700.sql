
DROP PROCEDURE IF EXISTS sp_sys_VentaEntradas_Entradas_F700_Cine

GO

CREATE PROCEDURE sp_sys_VentaEntradas_Entradas_F700_Cine
(
   @Id_Distribuidor INT,
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;

	
	DECLARE @Codigo_Incaa NVARCHAR(50)=NULL; 
	SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	WHERE c.Id_Evento=@Id_Evento;

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

		INSERT INTO @Calendario( Periodo, Fecha, Codigo_Sala  ) 
		SELECT DISTINCT @Periodo, @Fecha, REPLACE(sc.Codigo_Incaa,'_','') FROM sys_VentaEntradas_Ubicaciones_Salas_Cine sc

		SET @FECHA=DATEADD(DAY,1,@FECHA);
	END;

	DECLARE @Funciones TABLE(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Codigo_Pelicula NVARCHAR(50),
		FechaHora_Funcion DATETIME,
		Precio_Venta NUMERIC(18,3), 
		Precio_Sin_Impuesto NUMERIC(18,3), 
		Codigo_Distribuidor NVARCHAR(50),
		Codigo_Sala NVARCHAR(50),
		Tipo_Tarifa NVARCHAR(7) DEFAULT '', 
		Es_General BIT, 
		Serie NVARCHAR(50),
		Numero_Funcion INT
	)

	INSERT INTO @Funciones (Codigo_Pelicula, FechaHora_Funcion, Precio_Venta, Codigo_Distribuidor, Codigo_Sala, Es_General, Serie)
	SELECT DISTINCT evI.Codigo_Incaa AS Codigo_Pelicula, 
					f.Fecha AS FechaHora_Funcion, 
					Precio_Venta=CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  
										ELSE  fu.Precio END, 
					dI.Codigo_Incaa AS Codigo_Distribuidor,
					REPLACE(scI.Codigo_Incaa,'_','') AS Codigo_Sala,
					t.Es_Default ,
					(
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
			( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa LIKE '' OR  @Codigo_Incaa IS NULL )

			AND(  CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  ELSE  fu.Precio END IS NOT NULL AND CASE   WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  ELSE  fu.Precio END >0 )
			
			
	ORDER BY FechaHora_Funcion ASC, Codigo_Pelicula ASC,  Precio_Venta DESC
	
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
		DECLARE @Id_Funcion_General INT=NULL;

		SELECT TOP 1 @Id_Funcion_General=f.Id 
		FROM @Funciones f
		WHERE Codigo_Pelicula=@Codigo_Pelicula  AND Codigo_Pelicula=@Codigo_Pelicula AND Codigo_Sala=@Codigo_Sala AND FechaHora_Funcion=@FechaHora_Funcion 
				AND f.Es_General =1;
		
		IF(@Id_Funcion_General IS NULL)
		BEGIN
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

	
	DECLARE  CURSOR_Numeracion CURSOR FOR 
	SELECT DISTINCT f.FechaHora_Funcion, ROW_NUMBER() OVER (PARTITION BY CONVERT(DATE, f.FechaHora_Funcion) 
	ORDER BY f.FechaHora_Funcion) as nr FROM @Funciones f GROUP BY f.FechaHora_Funcion

	DECLARE @Fecha_Funcion DATETIME;
	DECLARE @Numero_Funcion INT;
	OPEN CURSOR_Numeracion;

	FETCH NEXT FROM CURSOR_Numeracion INTO @Fecha_Funcion, @Numero_Funcion;
	
	WHILE @@FETCH_STATUS =0
	BEGIN
		UPDATE @Funciones SET Numero_Funcion=@Numero_Funcion
		WHERE FechaHora_Funcion=@Fecha_Funcion

		FETCH NEXT FROM CURSOR_Numeracion INTO @Fecha_Funcion, @Numero_Funcion;
	END

	CLOSE CURSOR_Numeracion;
	DEALLOCATE CURSOR_Numeracion;

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

				evI.Codigo_Incaa AS Codigo_Pelicula,  
				REPLACE(LI.Codigo_Incaa,'_','') AS Codigo_Sala,
				dI.Codigo_Incaa AS Codigo_Distribuidor,

				f.Fecha AS FechaHora_Funcion,
				e.Entrada_Anulada, e.Activo, e.Cortesia  AS Es_Cortesia,

				Precio_Venta=CASE WHEN t_fu.Id IS NOT NULL  THEN t_fu.Precio  
							 ELSE  fu.Precio END 

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
	WHERE CONVERT(DATE, f.Fecha)>=@Fecha_Desde AND CONVERT(DATE, f.Fecha)<=@Fecha_Hasta 
				AND ( evI.Codigo_Incaa=@Codigo_Incaa OR @Codigo_Incaa LIKE '' OR  @Codigo_Incaa IS NULL ) 
				AND NOT (e.Entrada_Anulada=1 AND e.Cortesia=1)

	DECLARE @Entrada_Incaa TABLE
	(
		Id_Entrada INT,
		Codigo_Pelicula NVARCHAR(50),
		Codigo_Sala NVARCHAR(50),
		Codigo_Distribuidor NVARCHAR(50),
		Fecha_Funcion DATETIME,
		Precio_Tarifa NUMERIC(18,3),
		Tipo_Transaccion NVARCHAR(50), 
		Tipo_Distribucion NVARCHAR(50), 

		Precio_Base NUMERIC(18,3),
		Precio_Base_Final NUMERIC(18,3), 

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

		IF @Es_Anulada=0 AND @Es_Cortesia =1 
		BEGIN
			SET @Tipo_Distribucion='CORTESIA'; 
			SET @Tipo_Transaccion='NULL';

			SELECT @Precio_Tarifa=f.Precio_Venta 
			FROM @Funciones f
			INNER JOIN @Entradas e ON f.Codigo_Distribuidor=e.Codigo_Distribuidor AND f.Codigo_Pelicula=e.Codigo_Pelicula AND f.Codigo_Sala=e.Codigo_Sala AND f.FechaHora_Funcion=e.FechaHora_Funcion
			WHERE e.Id=@Id_Entrada AND f.Tipo_Tarifa like 'GENERAL';

			SET @MULT=0;
		END
			
		ELSE 
		BEGIN
			SET @Tipo_Distribucion='VENTA'; 
			SET @Tipo_Transaccion='NORMAL' 
		END

		SET @Precio_Base=@Precio_Tarifa/1.10 ;
		SET @Precio_Base_Final= @Precio_Base*@MULT;

		INSERT INTO @Entrada_Incaa(Id_Entrada, Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala,  Fecha_Funcion,  Precio_Tarifa, Precio_Base,  Precio_Base_Final, Tipo_Distribucion, Tipo_Transaccion)
		SELECT e.Id, e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.FechaHora_Funcion,  @Precio_Tarifa, @Precio_Base, @Precio_Base_Final, @Tipo_Distribucion, @Tipo_Transaccion 
		FROM @Entradas e 
		WHERE e.Id=@Id_Entrada
		
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
		
		Precio_Base Numeric(18,3),
		Precio_Base_Final DECIMAL(18,3),
		
		Numero_Primer_BOC INT,
		Total_Impuesto Numeric(18,3)
	)

	INSERT INTO @Resumen_Entrada(Codigo_Distribuidor, Codigo_Pelicula, Codigo_Sala, Fecha_Funcion, Precio_Tarifa, Precio_Base, Precio_Base_Final, Cantidad_Entrada, e.Tipo_Distribucion, Tipo_Transaccion)
	SELECT e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion,e.Precio_Tarifa, e.Precio_Base, e.Precio_Base_Final,  COUNT(*) AS Cantidad_Entrada, e.Tipo_Distribucion, e.Tipo_Transaccion 			
	FROM @Entrada_Incaa e
	GROUP BY e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Fecha_Funcion, e.Precio_Base_Final,  e.Precio_Tarifa, e.Tipo_Distribucion, e.Tipo_Transaccion , e.Precio_Base
	ORDER BY e.Fecha_Funcion, e.Codigo_Distribuidor, e.Codigo_Pelicula, e.Codigo_Sala, e.Precio_Tarifa DESC


	DECLARE CURSOR_REntrada CURSOR FOR SELECT re.ID FROM @Resumen_Entrada re
	DECLARE @Id_REntrada INT;

	OPEN CURSOR_REntrada;

	FETCH NEXT FROM CURSOR_REntrada INTO @Id_REntrada ;

	WHILE @@FETCH_STATUS=0
	BEGIN
		DECLARE @Primer_BOC INT=NULL;

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
								
	DECLARE @Bordereaux TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Periodo INT,
		Codigo_Sala NVARCHAR(50), 

		Fecha_Calendario DATE, 
		FechaHora_Funcion DATETIME, 

		Numero_Primer_Boc INT,

		Codigo_Pelicula NVARCHAR(50),
		Distribucion NVARCHAR(50),
		Codigo_Distribuidor NVARCHAR(50),
		Precio_Base NUMERIC(18,3),
		Impuesto  NUMERIC(18,3),
		Cantidad_Entradas INT,

		Total_Impuesto NUMERIC(18,3),

		Precio_Venta NUMERIC(18,3),
		Tipo_Transaccion NVARCHAR(50),
		Tipo_Distribucion NVARCHAR(50),

		Serie_Letra NVARCHAR(50),
		Orden_Serie INT,

		Numero_Funcion INT
	);


	INSERT INTO @Bordereaux (Periodo, Codigo_Sala, Fecha_Calendario, FechaHora_Funcion, Numero_Primer_Boc, Codigo_Pelicula, Distribucion, Codigo_Distribuidor, Precio_Base, Impuesto, Cantidad_Entradas, Total_Impuesto, Precio_Venta, Tipo_Transaccion, Tipo_Distribucion, Serie_Letra, Orden_Serie, Numero_Funcion)
	SELECT c.Periodo, c.Codigo_Sala,
			
			c.Fecha AS 'Fecha_Calendario',
			f.FechaHora_Funcion AS 'FechaHora_Funcion',
			
			re.Numero_Primer_Boc,
			
			f.Codigo_Pelicula, 
			Distribucion=CASE WHEN re.Tipo_Transaccion='NORMAL' OR re.Tipo_Distribucion='CORTESIA' THEN 'BASE'
							  WHEN re.Tipo_Transaccion='DEVOLUCION' THEN 'DEVO'
							  ELSE 'BASE' END,
			f.Codigo_Distribuidor,

			Precio_Base=CASE WHEN re.Tipo_Distribucion LIKE 'CORTESIA' THEN re.Precio_Base_Final ELSE f.Precio_Sin_Impuesto  END,
			Impuesto=f.Precio_Sin_Impuesto*0.1,

			ISNULL(re.Cantidad_Entrada,0) AS Cantidad_Entradas,

			ISNULL(re.Total_Impuesto,0.00) AS Total_Impuesto,

			ISNULL(f.Precio_Venta ,0.00),
			
			re.Tipo_Transaccion,
			re.Tipo_Distribucion,
			
			Letra_Tarifa=CASE WHEN re.Tipo_Distribucion='CORTESIA' THEN 'Z'
							  ELSE f.Serie END,
			
			Orden_Serie=CASE WHEN re.Tipo_Transaccion='DEVOLUSION' THEN 0 ELSE 1 END,
			
			F.Numero_Funcion
	FROM @Calendario c
	LEFT JOIN @Funciones f ON f.Codigo_Sala=c.Codigo_Sala AND CONVERT(DATE,f.FechaHora_Funcion)=c.Fecha
	LEFT JOIN @Resumen_Entrada re ON re.Codigo_Distribuidor=f.Codigo_Distribuidor AND
									re.Codigo_Pelicula=f.Codigo_Pelicula AND
									re.Codigo_Sala=f.Codigo_Sala AND
									re.Fecha_Funcion=f.FechaHora_Funcion AND 
									re.Precio_Tarifa=f.Precio_Venta
	ORDER BY c.Periodo ASC, c.Fecha ASC, c.Codigo_Sala ASC, f.FechaHora_Funcion ASC, f.Codigo_Pelicula ASC, f.Codigo_Distribuidor ASC, f.Precio_Venta DESC, Letra_Tarifa DESC, re.Tipo_Transaccion DESC

	SELECT  
			b.Periodo AS Periodo_Fiscal,
			b.Codigo_Sala AS Codigo_Sala,
			b.Fecha_Calendario AS Fecha_Calendario,
			b.FechaHora_Funcion AS Fecha_Hora_Funcion,
			b.Codigo_Pelicula AS Codigo_Pelicula,
			
			ISNULL(b.Distribucion,'BASE') Tipo_Funcion,
			
			b.Codigo_Distribuidor,
			
			Numero_Primer_Boc=ISNULL(CONVERT(VARCHAR(50),b.Numero_Primer_Boc),''),
			b.Orden_Serie AS Serie,
			
			ISNULL(b.Precio_Base,0.0) AS Precio_Basico,
			ISNULL(b.Impuesto,0.0) AS Impuesto,
			ISNULL(b.Cantidad_Entradas,0.0) AS Cantidad_Entradas, 
			ISNULL( b.Total_Impuesto,0.00) AS Total_Impuesto,
			
			0 AS Id_FuncionUbicacion,
			0 AS Id_Funcion,
			0 AS Id_Evento,
			0 AS Id_Tarifa_FuncionUbicacion,
			0 AS Id_Ubicacion,
			0 AS Id_Tarifa,
			
			ISNULL(b.Precio_Venta,0.0) AS Precio_Venta,
			
			Tipo_Entrada=CASE WHEN b.Tipo_Distribucion='CORTESIA' THEN 'CORTESIA'
							  WHEN b.Tipo_Transaccion='DEVOLUCION' THEN 'DEVOLUCION'
							  ELSE 'NORMAL' END,
			
			 Numero_Funcion=CASE WHEN b.Serie_Letra IS NULL THEN NULL ELSE  b.Numero_Funcion END ,
			
			b.Serie_Letra AS Letra_Tarifa
			
	FROM @Bordereaux b
	ORDER BY Periodo_Fiscal ASC, Codigo_Sala ASC, Fecha_Calendario ASC, Fecha_Hora_Funcion ASC, Codigo_Pelicula ASC, Codigo_Distribuidor ASC, Precio_Basico DESC, b.Serie_Letra DESC, b.Orden_Serie DESC

END

GO

DROP PROCEDURE IF EXISTS sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine

GO

CREATE PROCEDURE sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine
(
   @Id_Evento INT,
   @Fecha_Desde DATE,
   @Fecha_Hasta DATE
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Codigo_Incaa NVARCHAR(50)=NULL;
	SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	WHERE c.Id_Evento=@Id_Evento;

	DECLARE @Tiene_Argentores BIT='true';
	DECLARE @Porc_Argentores NUMERIC(18,2)=0.0;
	DECLARE @Porc_SAGAI NUMERIC(18,2)=0;
	SELECT TOP 1 @Tiene_Argentores=evI.Argentores,  
				 @Porc_Argentores=evI.Porcentaje_Argentores,           
				 @Porc_SAGAI=evI.Porcentaje_SAGAI           
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	WHERE ev.Id=@Id_Evento;

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
	EXEC sp_sys_VentaEntradas_Entradas_F700_Cine @Id_Distribuidor=0, @Id_Evento=@Id_Evento, @Fecha_Desde=@Fecha_Desde, @Fecha_Hasta=@Fecha_Hasta;

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

	DECLARE @Calendario TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Fecha DATE
	)
	INSERT INTO @Calendario(Fecha)
	SELECT e.Fecha_Calendario  FROM @Entradas e  GROUP BY e.Fecha_Calendario  ORDER BY e.Fecha_Calendario ASC;
	
	DECLARE @Precios TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Precio_Venta NUMERIC(18,3)
	)
	INSERT INTO @Precios SELECT e.Precio FROM @Entradas_Bordereaux e  GROUP BY e.Precio ORDER BY e.Precio DESC

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

		Cantidad_Total_Entradas INT,
		Monto_Diario NUMERIC(18,3),

		Argentores NUMERIC(18,3),
		Sagai NUMERIC(18,3)
	 )

	 INSERT INTO @Detalle (Fecha, Recaudacion_Entradas1, Cantidad_Entradas1, Recaudacion_Entradas2, Cantidad_Entradas2, Recaudacion_Entradas3, Cantidad_Entradas3, Recaudacion_Entradas4, Cantidad_Entradas4, Recaudacion_Entradas5, Cantidad_Entradas5, Cantidad_Total_Entradas, Monto_Diario, Argentores, Sagai)
	 SELECT c.Fecha,

			Recaudacion_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Cantidad_Entradas ELSE 0 END ),

			Cantidad_Total_Entradas=SUM(r.Cantidad_Entradas),
			Monto_Diario=SUM(r.Recaudacion),

			Argentores=0.0,
			Sagai=0
	 FROM @Resumen r
	 INNER JOIN @Calendario c ON c.Id=r.Id_Fecha
	 GROUP BY c.Fecha;

	 SELECT * FROM @Detalle

END


GO

DROP PROCEDURE IF EXISTS sp_sys_VentaEntradas_Entradas_Resumen_Periodo_Bordereaux_Cine

GO

CREATE PROCEDURE sp_sys_VentaEntradas_Entradas_Resumen_Periodo_Bordereaux_Cine
(
   @Id_Evento INT,
   @Desde DATE,
   @Hasta DATE
)
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @Codigo_Incaa NVARCHAR(50)=NULL;
	SELECT TOP 1 @Codigo_Incaa=c.Codigo_Incaa 
	FROM sys_VentaEntradas_Eventos_Peliculas_Cine c 
	WHERE c.Id_Evento=@Id_Evento;


	DECLARE @Tiene_Argentores BIT='true';
	DECLARE @Porc_Argentores NUMERIC(18,2)=0.0;
	DECLARE @Porc_SAGAI NUMERIC(18,2)=0;
	SELECT TOP 1 @Tiene_Argentores=evI.Argentores,  
				 @Porc_Argentores=evI.Porcentaje_Argentores,           
				 @Porc_SAGAI=evI.Porcentaje_SAGAI           
	FROM sys_VentaEntradas_Eventos ev
	INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=ev.Id 
	WHERE ev.Id=@Id_Evento;


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
	EXEC sp_sys_VentaEntradas_Entradas_F700_Cine @Id_Distribuidor=0, @Id_Evento=@Id_Evento, @Fecha_Desde=@Desde, @Fecha_Hasta=@Hasta;

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


	DECLARE @Calendario TABLE 
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Fecha DATE
	)
	INSERT INTO @Calendario(Fecha)
	SELECT e.Fecha_Calendario  FROM @Entradas e  GROUP BY e.Fecha_Calendario  ORDER BY e.Fecha_Calendario ASC;
	
	DECLARE @Precios TABLE
	(
		Id INT PRIMARY KEY IDENTITY(1,1),
		Precio_Venta NUMERIC(18,3)
	)
	INSERT INTO @Precios SELECT e.Precio FROM @Entradas_Bordereaux e  GROUP BY e.Precio ORDER BY e.Precio DESC


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

		Cantidad_Total_Entradas INT,
		Monto_Diario NUMERIC(18,3),

		Argentores NUMERIC(18,3),
		Sagai NUMERIC(18,3)
	 )

	 INSERT INTO @Detalle (Fecha, Recaudacion_Entradas1, Cantidad_Entradas1, Recaudacion_Entradas2, Cantidad_Entradas2, Recaudacion_Entradas3, Cantidad_Entradas3, Recaudacion_Entradas4, Cantidad_Entradas4, Recaudacion_Entradas5, Cantidad_Entradas5, Cantidad_Total_Entradas, Monto_Diario, Argentores, Sagai)
	 SELECT c.Fecha,

			Recaudacion_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_Entradas1=SUM(CASE WHEN  r.Id_Tarifa=1 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_2=SUM(CASE WHEN  r.Id_Tarifa=2 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_3=SUM(CASE WHEN  r.Id_Tarifa=3 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_4=SUM(CASE WHEN  r.Id_Tarifa=4 THEN r.Cantidad_Entradas ELSE 0 END ),

			Recaudacion_Entradas_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Recaudacion ELSE 0 END ),
			Cantidad_5=SUM(CASE WHEN  r.Id_Tarifa=5 THEN r.Cantidad_Entradas ELSE 0 END ),

			Cantidad_Total_Entradas=SUM(r.Cantidad_Entradas),
			Monto_Diario=SUM(r.Recaudacion),

			Argentores=0.0,
			Sagai=0
	 FROM @Resumen r
	 INNER JOIN @Calendario c ON c.Id=r.Id_Fecha
	 GROUP BY c.Fecha;

	 (
		 SELECT TOP 1
					Linea=1 ,
					Col1=SUM(CASE WHEN  p.Id=1 THEN p.Precio_Venta ELSE 0 END ),
					Col2=SUM(CASE WHEN  p.Id=2 THEN p.Precio_Venta ELSE 0 END ),
					Col3=SUM(CASE WHEN  p.Id=3 THEN p.Precio_Venta ELSE 0 END ),
					Col4=SUM(CASE WHEN  p.Id=5 THEN p.Precio_Venta ELSE 0 END ),
					Col5=SUM(CASE WHEN  p.Id=6 THEN p.Precio_Venta ELSE 0 END )
		 FROM @Precios p
	 )
	 UNION
	 (
		 SELECT TOP 1
					Linea=2 ,
					Col1=SUM(CASE WHEN  p.Id=1 THEN p.Precio_Venta /1.21 ELSE 0 END ),
					Col2=SUM(CASE WHEN  p.Id=2 THEN p.Precio_Venta /1.21  ELSE 0 END ),
					Col3=SUM(CASE WHEN  p.Id=3 THEN p.Precio_Venta /1.21  ELSE 0 END ),
					Col4=SUM(CASE WHEN  p.Id=5 THEN p.Precio_Venta /1.21  ELSE 0 END ),
					Col5=SUM(CASE WHEN  p.Id=6 THEN p.Precio_Venta /1.21  ELSE 0 END )
		 FROM @Precios p
	 )
	 UNION
	 (
		 SELECT TOP 1
					Linea=3 ,
					Col1=SUM( r.Recaudacion_Entradas1/1.21),
					Col2=SUM( r.Recaudacion_Entradas2/1.21 ),
					Col3=SUM( r.Recaudacion_Entradas3/1.21 ),
					Col4=SUM( r.Recaudacion_Entradas4/1.21 ),
					Col5=SUM( r.Recaudacion_Entradas5/1.21 )
		 FROM @Detalle r
	 )

END