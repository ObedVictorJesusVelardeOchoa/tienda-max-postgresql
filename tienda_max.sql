-- ===========================================
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ===========================================
CREATE DATABASE tienda_max;
\c tienda_max -- (En pgAdmin, conéctate a la base creada)

-- ===========================================
-- 2. CREACIÓN DE TABLAS
-- ===========================================
CREATE TABLE productos (
  id_producto SERIAL PRIMARY KEY,
  nombre_producto VARCHAR(100) NOT NULL,
  precio_unitario NUMERIC(10,2) NOT NULL,
  stock INT NOT NULL
);

CREATE TABLE clientes (
  dni VARCHAR(15) PRIMARY KEY,
  nombres VARCHAR(100) NOT NULL,
  apellido_paterno VARCHAR(50) NOT NULL,
  apellido_materno VARCHAR(50) NOT NULL
);

CREATE TABLE ventas (
  id_venta SERIAL PRIMARY KEY,
  dni_cliente VARCHAR(15) REFERENCES clientes(dni),
  id_producto INT REFERENCES productos(id_producto),
  cantidad INT NOT NULL,
  precio_total NUMERIC(10,2) NOT NULL,
  fecha_venta DATE DEFAULT CURRENT_DATE
);

CREATE TABLE proveedores (
  id_proveedor SERIAL PRIMARY KEY,
  nombre_proveedor VARCHAR(100) NOT NULL,
  id_producto INT REFERENCES productos(id_producto),
  fecha_embarque DATE NOT NULL,
  cantidad INT NOT NULL
);

-- ===========================================
-- 3. INSERCIÓN DE DATOS DE PRUEBA (5 registros por tabla)
-- ===========================================
INSERT INTO productos (nombre_producto, precio_unitario, stock) VALUES
('Laptop Lenovo', 2500.00, 10),
('Mouse Inalámbrico', 50.00, 100),
('Teclado Mecánico', 120.00, 50),
('Monitor Samsung', 800.00, 20),
('Impresora HP', 400.00, 15);

INSERT INTO clientes (dni, nombres, apellido_paterno, apellido_materno) VALUES
('12345678', 'Juan', 'Pérez', 'López'),
('87654321', 'María', 'Gómez', 'Ramírez'),
('13579246', 'Carlos', 'Sánchez', 'Torres'),
('24681357', 'Lucía', 'Martínez', 'Castro'),
('11223344', 'Ana', 'Rojas', 'Quispe');

INSERT INTO ventas (dni_cliente, id_producto, cantidad, precio_total, fecha_venta) VALUES
('12345678', 1, 1, 2500.00, '2024-05-01'),
('87654321', 2, 2, 100.00, '2024-05-02'),
('12345678', 3, 1, 120.00, '2024-05-03'),
('13579246', 4, 1, 800.00, '2024-05-04'),
('24681357', 5, 1, 400.00, '2024-05-05');

INSERT INTO proveedores (nombre_proveedor, id_producto, fecha_embarque, cantidad) VALUES
('Tech Supplies S.A.', 1, '2024-03-01', 5),
('Accesorios Perú', 2, '2024-03-05', 50),
('Accesorios Perú', 3, '2024-03-07', 30),
('Monitores SAC', 4, '2024-03-10', 10),
('Impresoras Lima', 5, '2024-03-12', 8);

-- ===========================================
-- 4. CONSULTAS SQL (JOINs, SUBCONSULTAS, FUNCIONES AGREGADAS)
-- ===========================================

-- a) INNER JOIN: Ventas con nombres de clientes y productos
SELECT 
    v.id_venta,
    c.nombres || ' ' || c.apellido_paterno AS nombre_cliente,
    p.nombre_producto,
    v.cantidad,
    v.precio_total,
    v.fecha_venta
FROM ventas v
JOIN clientes c ON v.dni_cliente = c.dni
JOIN productos p ON v.id_producto = p.id_producto;

-- b) LEFT JOIN: Todas las ventas y productos, incluyendo los que no tienen cliente asignado
SELECT 
    v.id_venta,
    c.nombres || ' ' || c.apellido_paterno AS nombre_cliente,
    p.nombre_producto,
    v.cantidad,
    v.precio_total,
    v.fecha_venta
FROM ventas v
LEFT JOIN clientes c ON v.dni_cliente = c.dni
LEFT JOIN productos p ON v.id_producto = p.id_producto;

-- c) Subconsulta: Productos con precio superior al promedio
SELECT nombre_producto, precio_unitario
FROM productos
WHERE precio_unitario > (
    SELECT AVG(precio_unitario) FROM productos
);

-- d) Subconsulta: Clientes que han gastado más de 100 soles
SELECT nombres, apellido_paterno
FROM clientes
WHERE dni IN (
    SELECT dni_cliente
    FROM ventas
    GROUP BY dni_cliente
    HAVING SUM(precio_total) > 100
);

-- e) Funciones agregadas: Total de ventas por cliente
SELECT 
    c.nombres || ' ' || c.apellido_paterno AS cliente,
    SUM(v.precio_total) AS total_gastado
FROM ventas v
JOIN clientes c ON v.dni_cliente = c.dni
GROUP BY c.dni;

-- f) Función agregada: Promedio de stock de productos
SELECT AVG(stock) AS promedio_stock FROM productos;

-- g) Máximo y mínimo precio de productos
SELECT MAX(precio_unitario) AS precio_maximo, MIN(precio_unitario) AS precio_minimo FROM productos;

-- ===========================================
-- 5. PROCEDIMIENTOS ALMACENADOS (PL/pgSQL)
-- ===========================================

-- a) Procedimiento para actualizar/incrementar inventario
CREATE OR REPLACE PROCEDURE actualizacion_inventario(
    p_nombre_producto VARCHAR,
    p_stock INTEGER,
    p_precio NUMERIC(10,2)
)
LANGUAGE plpgsql
AS $$
DECLARE
    existencia_fila INTEGER;
BEGIN
    UPDATE productos
    SET stock = stock + p_stock
    WHERE nombre_producto = p_nombre_producto;
    GET DIAGNOSTICS existencia_fila = ROW_COUNT;
    IF existencia_fila = 0 THEN
        INSERT INTO productos (nombre_producto, precio_unitario, stock)
        VALUES (p_nombre_producto, p_precio, p_stock);
        RAISE NOTICE 'Producto % no existía. Se agregó con precio S/%.2f y stock %.', p_nombre_producto, p_precio, p_stock;
    ELSE
        RAISE NOTICE 'Inventario actualizado con éxito para %.', p_nombre_producto;
    END IF;
END;
$$;

-- b) Procedimiento para insertar una venta y actualizar stock
CREATE OR REPLACE PROCEDURE insertar_venta_inteligente(
    p_dni_cliente VARCHAR,
    p_id_producto INT,
    p_cantidad INT,
    p_precio_total NUMERIC(10,2),
    p_confirmar_registro_cliente BOOLEAN,
    p_nombres VARCHAR DEFAULT NULL,
    p_apellido_paterno VARCHAR DEFAULT NULL,
    p_apellido_materno VARCHAR DEFAULT NULL,
    p_fecha_venta DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cliente_existe BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM clientes WHERE dni = p_dni_cliente) INTO v_cliente_existe;
    IF NOT v_cliente_existe THEN
        IF p_confirmar_registro_cliente THEN
            INSERT INTO clientes (dni, nombres, apellido_paterno, apellido_materno)
            VALUES (p_dni_cliente, p_nombres, p_apellido_paterno, p_apellido_materno);
            RAISE NOTICE 'Cliente registrado correctamente con DNI %', p_dni_cliente;
        ELSE
            RAISE NOTICE 'Cliente no registrado. La venta se asociará sin cliente.';
            p_dni_cliente := NULL;
        END IF;
    END IF;
    INSERT INTO ventas (dni_cliente, id_producto, cantidad, precio_total, fecha_venta)
    VALUES (p_dni_cliente, p_id_producto, p_cantidad, p_precio_total, p_fecha_venta);
    UPDATE productos
    SET stock = stock - p_cantidad
    WHERE id_producto = p_id_producto;
    RAISE NOTICE 'Venta registrada correctamente.';
END;
$$;

-- ===========================================
-- 6. GESTIÓN DE ROLES Y USUARIOS
-- ===========================================

-- Revocar permisos públicos
REVOKE ALL ON DATABASE tienda_max FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- Crear roles
CREATE ROLE rol_supremo2;
CREATE ROLE rol_lectura2;
CREATE ROLE rol_ventas2;
CREATE ROLE rol_inventario2;

-- Asignar permisos a roles
GRANT SELECT, INSERT ON ventas TO rol_ventas2;
GRANT SELECT, UPDATE ON productos TO rol_inventario2;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rol_supremo2;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO rol_supremo2;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_lectura2;

-- Crear usuarios y asignar roles
CREATE USER el_hechicero_supremo2 WITH PASSWORD 'Lucas';
CREATE USER usuario_lectura2 WITH PASSWORD 'lector';
CREATE USER jesus_ventas2 WITH PASSWORD 'freestyle';
CREATE USER josue_inventario2 WITH PASSWORD 'billar';

GRANT rol_supremo2 TO el_hechicero_supremo2;
GRANT rol_lectura2 TO usuario_lectura2;
GRANT rol_ventas2 TO jesus_ventas2;
GRANT rol_inventario2 TO josue_inventario2;

-- ===========================================
-- FIN DEL SCRIPT
-- ===========================================