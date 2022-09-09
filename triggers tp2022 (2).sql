-- ACTUALIZAR EL TIEMPO DE DEMORA MAXIMO DE UN PEDIDO
/*CREATE TRIGGER dbo.tr_demora ON Producto_Pedido AFTER INSERT AS 
BEGIN
	DECLARE @tiempo_prod INT, @cod_prod INT, @num_pedido INT, @tiempo_max INT

	SELECT @cod_prod = inserted.codigo_producto,@num_pedido = inserted.numero_pedido FROM inserted
	SELECT @tiempo_max = tiempo_demora_max FROM Pedido WHERE numero = @num_pedido
	SELECT @tiempo_prod = temp_demora FROM Producto WHERE codigo = @cod_prod

	IF (@tiempo_prod > @tiempo_max) UPDATE Pedido SET tiempo_demora_max = @tiempo_prod WHERE numero = @num_pedido
END;
*/

-- CALCULAR EL TIEMPO DE DEMORA MAXIMO DEL PEDIDO

CREATE OR ALTER TRIGGER dbo.tr_demora ON Producto_Pedido AFTER INSERT, UPDATE, DELETE AS 
BEGIN
	DECLARE @num_pedido INT, @tiempo_max INT

	IF (EXISTS(SELECT * FROM INSERTED)) 
		SELECT @num_pedido = inserted.numero_pedido FROM inserted	
	ELSE IF (EXISTS(SELECT * FROM DELETED))	
		SELECT @num_pedido = deleted.numero_pedido FROM deleted

	SET @tiempo_max = (SELECT dbo.f_mayor_demora(@num_pedido))
	UPDATE Pedido SET tiempo_demora_max = @tiempo_max WHERE numero = @num_pedido	
END;

--DROP TRIGGER dbo.tr_demora

-- ACTUALIZAR EL SUBTOTAL DE UNA CUENTA DESPUES DE AGREGAR UN PRODUCTO
/*CREATE OR ALTER TRIGGER dbo.tr_subtotal ON Producto_Pedido AFTER INSERT AS 
BEGIN
	DECLARE @cod_prod INT, @cant_prod INT, @precio_prod DECIMAL, @num_pedido INT, @num_cuenta INT
	
	SELECT @cod_prod = inserted.codigo_producto, @cant_prod = inserted.cantidad, @num_pedido = inserted.numero_pedido FROM inserted
	SELECT @precio_prod = precio FROM Producto WHERE codigo = @cod_prod
	SELECT @num_cuenta = numero_cuenta FROM Pedido_Salon WHERE numero_pedido = @num_pedido
	
	UPDATE Cuenta SET subtotal = subtotal + @precio_prod * @cant_prod WHERE numero = @num_cuenta
END;*/

/*
CREATE OR ALTER TRIGGER dbo.tr_subtotal ON Producto_Pedido AFTER INSERT, UPDATE, DELETE AS 
BEGIN
	DECLARE @cod_prod INT, @cant_prod INT, @precio_prod DECIMAL, @num_pedido INT, @num_cuenta INT

	IF (EXISTS(SELECT * FROM inserted))
	BEGIN
		SELECT @cod_prod = inserted.codigo_producto, @cant_prod = inserted.cantidad, @num_pedido = inserted.numero_pedido FROM inserted
		--SELECT @precio_prod = precio FROM Producto WHERE codigo = @cod_prod
		SELECT @num_cuenta = numero_cuenta FROM Pedido_Salon WHERE numero_pedido = @num_pedido
		--UPDATE Cuenta SET subtotal = subtotal + @precio_prod * @cant_prod WHERE numero = @num_cuenta
	END
	IF (EXISTS(SELECT * FROM deleted))
	BEGIN
		SELECT @cod_prod = deleted.codigo_producto, @cant_prod = deleted.cantidad, @num_pedido = deleted.numero_pedido FROM deleted
		--SELECT @precio_prod = precio FROM Producto WHERE codigo = @cod_prod
		SELECT @num_cuenta = numero_cuenta FROM Pedido_Salon WHERE numero_pedido = @num_pedido
		--UPDATE Cuenta SET subtotal = subtotal - @precio_prod * @cant_prod WHERE numero = @num_cuenta -- ME BORRA 1 SOLO NO SE POR QUE
	END
	UPDATE Cuenta SET subtotal = (SELECT dbo.f_calcular_subtotal(@num_cuenta))
END;*/



-- DEFINE EL ESTADO DE LA MESA

CREATE OR ALTER TRIGGER dbo.tr_estado_mesa ON Cuenta AFTER INSERT, DELETE AS 
BEGIN
	DECLARE @num_mesa INT
	IF (EXISTS(SELECT * FROM inserted))
	BEGIN
		SELECT @num_mesa = inserted.nro_mesa FROM inserted
		UPDATE Mesa SET estado = 'True' WHERE numero = @num_mesa
	END;
	ELSE IF (EXISTS(SELECT * FROM deleted))
	BEGIN
		SELECT @num_mesa = deleted.nro_mesa FROM deleted
		UPDATE Mesa SET estado = 'False' WHERE numero = @num_mesa
		DECLARE @num_pedido INT
		SELECT @num_pedido FROM deleted LEFT JOIN Pedido_Salon ON deleted.numero = Pedido_Salon.numero_cuenta
		LEFT JOIN Pedido ON Pedido_salon.numero_pedido = Pedido.numero
		DELETE FROM Pedido WHERE numero = @num_pedido
	END;
END;


-- Calculo del subtotal de la cuenta: 

CREATE OR ALTER FUNCTION f_calcular_subtotal(@nro_cuenta int)
RETURNS DECIMAL(19,2) AS
BEGIN
	DECLARE @total DECIMAL(12,3)
	SELECT @total = (
		select sum (Producto_Pedido.cantidad * Producto.precio) from Producto_Pedido
		join Producto on Producto.codigo = Producto_Pedido.numero_pedido
		join Pedido_Salon on Pedido_Salon.numero_pedido = Producto_Pedido.numero_pedido
		join Cuenta on Cuenta.numero = @nro_cuenta
	);
	RETURN @total
END;





-- CALCULO DEL SUBTOTAL DE LA CUENTA

CREATE OR ALTER TRIGGER dbo.tr_subtotal ON Producto_Pedido AFTER INSERT, UPDATE, DELETE AS 
BEGIN
	DECLARE @num_pedido INT, @num_cuenta INT

	IF (EXISTS(SELECT * FROM inserted))
	BEGIN
		SELECT @num_pedido = inserted.numero_pedido FROM inserted
		SELECT @num_cuenta = numero_cuenta FROM Pedido_Salon WHERE numero_pedido = @num_pedido
	END
	ELSE IF (EXISTS(SELECT * FROM deleted))
	BEGIN
		SELECT @num_pedido = deleted.numero_pedido FROM deleted
		SELECT @num_cuenta = numero_cuenta FROM Pedido_Salon WHERE numero_pedido = @num_pedido
	END
	UPDATE Cuenta SET subtotal = (SELECT dbo.f_calcular_subtotal(@num_cuenta)) WHERE numero = @num_cuenta
END;

-- pedido con mayor demora: 

CREATE OR ALTER FUNCTION f_mayor_demora(@nro_pedido int)
RETURNS INT AS
BEGIN 
	DECLARE @mayor_demora INT
	SELECT @mayor_demora = (SELECT TOP 1 tiempo_demora FROM Producto_Pedido
								LEFT JOIN Producto ON codigo_producto = codigo 
								ORDER BY tiempo_demora DESC)
	IF (@mayor_demora IS NULL) RETURN 0
	RETURN @mayor_demora
END;


--CANTIDAD DE PEDIDOS ENTRE DOS FECHAS:

CREATE OR ALTER FUNCTION fn_cant_pedidos(@fecha1 DATETIME2, @fecha2 DATETIME2)
RETURNS INT AS
BEGIN
	DECLARE @cantidad INT
	SELECT @cantidad = COUNT(numero) FROM Pedido FOR SYSTEM_TIME BETWEEN @fecha1 AND @fecha2
	RETURN @cantidad
END;

------ vista de COLA DE pedidos------
CREATE or alter VIEW v_colaPedidos AS
  SELECT 
    p.numero,
    DATEADD (HOUR, -3, p.fyh_inicio) as inicioPedido,
    p.tiempo_demora_max as demoraEstimada, 
    DATEDIFF (MINUTE,
          DATEADD (HOUR, -3, p.fyh_inicio), 
          GETDATE() 
        ) as demoraActual,
    p.nivel 
  FROM Pedido as p WHERE p.estado = 0;


--calcular nivel de demora:

CREATE OR ALTER FUNCTION dbo.sp_nivelDemora(@nro_pedido int)
RETURNS int
AS 
BEGIN
  Declare @demoraestimada int, @demoraactual int;
  SELECT @demoraestimada = p.demoraEstimada, @demoraactual = p.demoraActual  FROM dbo.v_colaPedidos p WHERE p.numero = @nro_pedido;
  if ( @demoraactual > @demoraestimada)
    return 1;
  else if ( @demoraactual >= (@demoraestimada * 0.8) )
      return 2;
  
  return 3;
END

--select * from dbo.v_colaPedidos;
--select dbo.sp_nivelDemora(2) as nivel;

-- PRUEBA DE LA COLA DE PEDIDOS CON NIVEL
create or alter procedure prueba
as begin
	select numero,inicioPedido,demoraEstimada,demoraActual,dbo.sp_nivelDemora(numero) AS Nivel from v_colaPedidos
	ORDER BY Nivel,inicioPedido;
end;

exec prueba;
--
-- CAMBIA ESTADO A ENTREGADO Y ELIMINA EL PEDIDO.
CREATE OR ALTER Procedure pr_entregar_pedido @nro_pedido INT
AS BEGIN
	UPDATE Pedido SET estado = 2 WHERE numero = @nro_pedido
	DELETE FROM Pedido WHERE numero = @nro_pedido
END;

exec pr_entregar_pedido 2

-- CAMBIA ESTADO A EN PREPARACION.
CREATE OR ALTER Procedure pr_entregar_pedido @nro_pedido INT
AS BEGIN
	UPDATE Pedido SET estado = 1 WHERE numero = @nro_pedido
END;

-- FUNCION PARA SACAR EL TIEMPO ELABORACION

CREATE OR ALTER FUNCTION fn_tiempo_elaboracion(@nro_pedido INT)
RETURNS INT AS BEGIN
	DECLARE @inicio DATETIME2,@fin DATETIME2
	SELECT TOP 1 @inicio = fyh_inicio FROM Pedido FOR SYSTEM_TIME ALL WHERE numero = @nro_pedido ORDER BY fyh_inicio
	SELECT TOP 1 @fin = fyh_fin FROM Pedido FOR SYSTEM_TIME ALL WHERE numero = @nro_pedido ORDER BY fyh_fin DESC
	RETURN (SELECT DATEDIFF (MINUTE, DATEADD (HOUR, 0, @inicio), @fin)
	FROM Pedido FOR SYSTEM_TIME ALL WHERE numero = @nro_pedido AND Estado = 1)
END;

-- VISTA CON PEDIDOS ENTREGADOS

CREATE OR ALTER VIEW v_pedidos_entregados AS
SELECT *,dbo.fn_tiempo_elaboracion(numero) AS 'Tiempo Elaboración' FROM Pedido FOR SYSTEM_TIME ALL WHERE estado = 2

--SELECT * FROM v_pedidos_entregados

-- PROMEDIO DE TIEMPO DE ELABORACION DE PEDIDOS POR SEMANA

CREATE OR ALTER FUNCTION fn_promedio_semanal(@cant_semanas INT)
RETURNS INT AS BEGIN
	RETURN (SELECT AVG(dbo.fn_tiempo_elaboracion(numero)) AS 'Tiempo Elaboracion' FROM Pedido FOR SYSTEM_TIME ALL WHERE fyh_inicio
	BETWEEN DATEADD(DAY, @cant_semanas*-7, GETDATE()) AND DATEADD(DAY, (@cant_semanas-1)*-7, GETDATE()) AND estado = 2)
END;

--SELECT dbo.fn_promedio_semanal(1)


-- INSERT, DELETE Y SELECT DE LAS TABLAS

INSERT INTO Producto VALUES (10,'Pizza',350,30);
INSERT INTO Producto VALUES (20,'Hamburguesa',250,10);
INSERT INTO Producto VALUES (30,'Milanesa',300,20);
INSERT INTO Producto VALUES (40,'Sanguche',225,8);

--SELECT * FROM Producto

INSERT INTO Pedido (numero,tiempo_demora_max,nivel,estado) VALUES ((SELECT COUNT(*)+1 FROM Pedido),0,3,0);
INSERT INTO Pedido (numero,tiempo_demora_max,nivel,estado) VALUES ((SELECT COUNT(*)+1 FROM Pedido),0,3,0);

--SELECT * FROM Pedido
--DELETE FROM Pedido
--DELETE FROM Pedido WHERE numero = 2;

INSERT INTO Producto_Pedido VALUES (1,20,4);
INSERT INTO Producto_Pedido VALUES (1,40,2);
INSERT INTO Producto_Pedido VALUES (1,10,2);

INSERT INTO Producto_Pedido VALUES (2,40,3);

SELECT * FROM Producto_Pedido
DELETE FROM Producto_Pedido WHERE numero_pedido = 1

INSERT INTO Mesa VALUES (1,'False');
SELECT * FROM Mesa

INSERT INTO Cuenta (numero,nro_mesa,subtotal) VALUES (271,1,0);
SELECT * FROM Cuenta
DELETE FROM Cuenta


INSERT INTO Pedido_Salon VALUES (100,1,271);
INSERT INTO Pedido_Salon VALUES (200,2,271);

SELECT * FROM Pedido_Salon
DELETE FROM Pedido_Salon



--
SELECT SUM(precio * cantidad) FROM Cuenta 
	LEFT JOIN Pedido_Salon ON Cuenta.numero = numero_cuenta 
	LEFT JOIN Producto_Pedido ON Pedido_Salon.numero_pedido = Producto_Pedido.numero_pedido 
	LEFT JOIN Producto ON codigo_producto = Producto.codigo 
	GROUP BY Pedido_Salon.numero_pedido,Cuenta.numero


SELECT * FROM Cuenta

SELECT * FROM Producto_Pedido

SELECT * FROM Pedido_Salon
SELECT dbo.f_mayor_demora(1)


SELECT * FROM Pedido FOR SYSTEM_TIME BETWEEN '2021-01-01 00:00:00.0000000' AND '2023-01-01 00:00:00.0000000'
SELECT dbo.fn_cant_pedidos('2021-01-01 00:00:00.0000000','2023-01-01 00:00:00.0000000')

SELECT * FROM Pedido
SELECT * FROM Mesa
SELECT * FROM Cuenta
SELECT * FROM Pedido_Salon

SELECT * FROM Cuenta LEFT JOIN Pedido_Salon ON Cuenta.numero = numero_cuenta 


SELECT nro_mesa,numero_cuenta,numero_pedido,subtotal,Pedido.fyh_inicio,Pedido.fyh_fin FROM Mesa LEFT JOIN Cuenta ON Mesa.numero = Cuenta.nro_mesa LEFT JOIN Pedido_Salon ON numero_cuenta = Cuenta.numero
LEFT JOIN Pedido FOR SYSTEM_TIME ALL ON Pedido_Salon.numero_pedido = Pedido.numero

---

select * from v_colaPedidos p
  order by p.nivel, p.inicioPedido asc;

select DATEADD (HOUR, -3, inicioPedido) from v_colaPedidos;





--- nuevas funciones --- 



-- VISTA CON PEDIDOS ENTREGADOS

CREATE OR ALTER VIEW v_pedidos_entregados AS
SELECT *,dbo.fn_tiempo_elaboracion(numero) AS 'Tiempo Elaboración' FROM Pedido FOR SYSTEM_TIME ALL WHERE estado = 2

--SELECT * FROM v_pedidos_entregados

-- PROMEDIO DE TIEMPO DE ELABORACION DE PEDIDOS POR SEMANA

CREATE OR ALTER FUNCTION fn_promedio_semanal(@cant_semanas INT)
RETURNS INT AS BEGIN
	RETURN (SELECT AVG(dbo.fn_tiempo_elaboracion(numero)) AS 'Tiempo Elaboracion' FROM Pedido FOR SYSTEM_TIME ALL WHERE fyh_inicio
	BETWEEN DATEADD(DAY, @cant_semanas*-7, GETDATE()) AND DATEADD(DAY, (@cant_semanas-1)*-7, GETDATE()) AND estado = 2)
END;