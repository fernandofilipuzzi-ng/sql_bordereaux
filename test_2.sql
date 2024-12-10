
--USE BD_MUNICIPALIDADORAN
--USE BD_MINACLAVERO
USE BD_CINEMALVINAS
--USE BD_MUNICIPALIDADMALARGUE
--USE BD_CINEOPENPLAZA
---USE BD_MUNICIPALIDADMALARGUE

GO

DECLARE @Desde DATE='12-1-2024';
DECLARE @Hasta DATE='12-6-2024';

EXEC sp_sys_VentaEntradas_Entradas_F700_Cine_2 0,0,@Desde,@Hasta


DECLARE @Codigo NVARCHAR(50)='046719'

DECLARE @Id_Evento INT=NULL

SELECT @Id_Evento=ev.Id  FROM sys_VentaEntradas_Eventos ev INNER JOIN sys_VentaEntradas_Eventos_Peliculas_Cine evI ON evI.Id_Evento=EV.Id
WHERE evI.Codigo_Incaa=@Codigo;

EXEC sp_sys_VentaEntradas_Entradas_Diario_Bordereaux_Cine_2 @Id_Evento, @Desde,@Hasta
EXEC sp_sys_VentaEntradas_Entradas_Resumen_Periodo_Bordereaux_Cine_2 @Id_Evento, @Desde,@Hasta