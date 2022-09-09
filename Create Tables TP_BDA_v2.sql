--ALTER TABLE dbo.Pedido SET ( SYSTEM_VERSIONING = OFF);
--drop table dbo.Pedido;

CREATE TABLE Producto (
	codigo INT NOT NULL,
	nombre NVARCHAR(50) NOT NULL,
	precio DECIMAL(19,2) NOT NULL,
	tiempo_demora INT,
	CONSTRAINT PK_Producto PRIMARY KEY CLUSTERED (codigo)
);

CREATE TABLE Mesa (
	numero INT NOT NULL,
	estado BIT NOT NULL,
	CONSTRAINT PK_Mesa PRIMARY KEY CLUSTERED (numero)
);

CREATE TABLE Pedido (
	numero INT NOT NULL,
	fyh_inicio DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
	fyh_fin DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
	tiempo_demora_max INT,
	nivel INT NOT NULL,
	estado BIT NOT NULL,
	PERIOD FOR SYSTEM_TIME (fyh_inicio, fyh_fin),
	CONSTRAINT PK_Pedido PRIMARY KEY CLUSTERED (numero)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.Pedido_Historia));


--ALTER TABLE Pedido ADD estado BIT NOT NULL
--ALTER TABLE Pedido SET (SYSTEM_VERSIONING = OFF)
--SELECT * FROM Pedido_Historia
DROP TABLE Pedido_Delivery
DROP TABLE Pedido_Salon
DROP TABLE Pedido
DROP Table Producto_Pedido
SELECT * FROM Cuenta


CREATE TABLE Pedido_Delivery (
	id INT NOT NULL,
	numero_pedido INT NOT NULL,
	dir_calle NVARCHAR(50) NOT NULL,
	dir_numero INT NOT NULL,
	dir_nro_dpto INT NOT NULL,
	dir_nro_piso INT NOT NULL,
	observaciones NVARCHAR(150) NOT NULL,
	CONSTRAINT PK_Pedido_Delivery PRIMARY KEY CLUSTERED (id),
	CONSTRAINT FK_PedidoDelivery_Pedido FOREIGN KEY (numero_pedido) REFERENCES Pedido (numero) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE Cuenta (
	numero INT NOT NULL,
	nro_mesa INT not null,
	fyh_inicio DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
	fyh_fin DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
	subtotal DECIMAL(19,2),
	PERIOD FOR SYSTEM_TIME (fyh_inicio, fyh_fin),
	CONSTRAINT PK_Cuenta PRIMARY KEY CLUSTERED (numero),
	CONSTRAINT FK_Cuenta_Mesa FOREIGN KEY (nro_mesa) REFERENCES Mesa(numero) ON UPDATE CASCADE ON DELETE CASCADE
)WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.Cuenta_Historia));

CREATE TABLE Pedido_Salon (
	id INT NOT NULL,
	numero_pedido INT NOT NULL,
	numero_cuenta INT NOT NULL,
	CONSTRAINT PK_Pedido_Salon PRIMARY KEY CLUSTERED (id),
	CONSTRAINT FK_PedidoSalon_Pedido FOREIGN KEY (numero_pedido) REFERENCES Pedido (numero) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT FK_Pedido_Cuenta FOREIGN KEY (numero_cuenta) REFERENCES Cuenta (numero) ON UPDATE CASCADE ON DELETE CASCADE
)

CREATE TABLE Producto_Pedido (
	numero_pedido INT NOT NULL,
	codigo_producto INT NOT NULL,
	cantidad INT NOT NULL,
	CONSTRAINT PK_Producto_Pedido PRIMARY KEY CLUSTERED (numero_pedido, codigo_producto),
	CONSTRAINT FK_ProductoPedido_Pedido FOREIGN KEY (numero_pedido) REFERENCES Pedido (numero) ON UPDATE CASCADE ON DELETE CASCADE,
	CONSTRAINT FK_ProductoPedido_Producto FOREIGN KEY (codigo_producto) REFERENCES Producto (codigo) ON UPDATE CASCADE ON DELETE CASCADE,
)

--Funciones y disparadores:
-- Nivel 1: El pedido ha superado el tiempo de preparación asignado.
-- Nivel 2: falta un 20% del tiempo para que se cumpla el tiempo de preparación.
-- Nivel 3: Pedidos no incluídos en los niveles anteriores.
create function f_nro_pedidos (@nro_pedido int)
 returns int
 as
 begin 
   declare @nivel int
	if select   fyh_inicio into @fyh, tiempo_demora_max from 
   --set @nivel=(@valor1+@valor2)/2
   return @nivel
 end;

--DROP FUNCTION f_promedio



