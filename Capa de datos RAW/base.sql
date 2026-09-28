CREATE DATABASE PRACTICA_FINAL_NUEVA;

CREATE SCHEMA IF NOT EXISTS RAW;

CREATE OR REPLACE TABLE CUSTOMER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;

CREATE OR REPLACE TABLE LINEITEM AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

CREATE OR REPLACE TABLE ORDERS AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;

CREATE OR REPLACE TABLE PART AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART;

CREATE OR REPLACE TABLE SUPPLIER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER;

CREATE OR REPLACE TABLE NATION AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION;

CREATE OR REPLACE TABLE REGION AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION;

CREATE OR REPLACE TABLE PARTSUPP AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP;

CREATE OR REPLACE TABLE RAW.TIENDA (
    ID_TIENDA INT PRIMARY KEY,
    NOMBRE_TIENDA VARCHAR(100),
    ID_PAIS INT 
);

INSERT INTO RAW.TIENDA (ID_TIENDA, NOMBRE_TIENDA, ID_PAIS) VALUES 
    (1,  'Tienda Riad', 20),
    (2,  'Tienda Pekín', 18),
    (3,  'Tienda Maputo', 16),
    (4,  'Tienda Nairobi', 14),
    (5,  'Tienda Tokio', 12),
    (6,  'Tienda Teherán', 10),
    (7,  'Tienda Nueva Delhi', 8),
    (8,  'Tienda París', 6),
    (9,  'Tienda El Cairo', 4),
    (10, 'Tienda San Pablo', 2);


ALTER TABLE RAW.ORDERS ADD COLUMN ID_TIENDA INT;

UPDATE ORDERS SET ID_TIENDA = UNIFORM (1, 10, RANDOM());

CREATE OR REPLACE TABLE PROMOCION(
    ID_PROMOCION INT PRIMARY KEY, 
    NOMBRE_PROMOCION VARCHAR (100),
    FECHA_INICIO DATE,
    FECHA_FIN DATE,
    DESCUENTO NUMBER(38,2)
);

INSERT INTO RAW.PROMOCION (ID_PROMOCION, NOMBRE_PROMOCION, FECHA_INICIO, FECHA_FIN, DESCUENTO)

SELECT 
    ROW_NUMBER() OVER (ORDER BY a.ano, p.id) as ID_PROMOCION,
    p.nombre as NOMBRE_PROMOCION,
    DATE_FROM_PARTS( a.ano, p.mes_ini, p.dia_ini) as FECHA_INICIO,
    DATE_FROM_PARTS(a.ano, p.mes_fin, p.dia_fin) as FECHA_FIN,
    p.DESCUENTO AS DESCUENTO,
    FROM ( VALUES (1992),(1993),(1994),(1995),(1996),(1997),(1998) ) AS a(ano) 
    CROSS JOIN 
    (VALUES (1, 'Campaña Navideña', 12, 1, 12, 31, 20.00),
        (2, 'Especial Semana Santa', 3, 25, 4, 5, 15.00),
        (3, 'Rebajas de Verano', 7, 1, 8, 31, 30.00),
        (4, 'Black Friday', 11, 20, 11, 30, 50.00),
        (5, 'Cyber Monday', 12, 1, 12, 2, 40.00),
        (6, 'Vuelta al Cole', 8, 15, 9, 15, 25.00),
        (7, 'Especial Día de la Madre', 4, 28, 5, 3, 10.00),
        (8, 'Promoción Halloween', 10, 25, 11, 1, 15.50),
        (9, 'Mid-Season Sale Primavera', 5, 10, 5, 20, 35.00))
        AS p(id, nombre, mes_ini, dia_ini, mes_fin, dia_fin, descuento);

select * from raw.promocion;

CREATE OR REPLACE TABLE PROMOCION_PAIS(
    ID_PROMOCION INT , 
    ID_PAIS INT
);

INSERT INTO RAW.PROMOCION_PAIS (ID_PROMOCION, ID_PAIS)
WITH REGLAS_GEOGRAFICAS AS (
    SELECT base_id, id_pais
    FROM (
        VALUES
        (1, 1), (1, 2), (1, 3), (1, 6), (1, 7), (1, 17), (1, 19), (1, 22), (1, 23), (1, 24),
        (2, 1), (2, 2), (2, 6), (2, 7), (2, 17), (2, 19), (2, 23),
        (3, 3), (3, 6), (3, 7), (3, 8), (3, 12), (3, 18), (3, 19), (3, 22), (3, 23), (3, 24),
        (4, 1), (4, 2), (4, 3), (4, 6), (4, 7), (4, 12), (4, 18), (4, 23), (4, 24),
        (5, 1), (5, 2), (5, 3), (5, 6), (5, 7), (5, 12), (5, 18), (5, 23), (5, 24),
        (6, 1), (6, 2), (6, 3), (6, 6), (6, 7), (6, 8), (6, 12), (6, 18), (6, 23), (6, 24),
        (7, 1), (7, 2), (7, 3), (7, 6), (7, 7), (7, 17), (7, 23), (7, 24),
        (8, 1), (8, 2), (8, 3), (8, 23), (8, 24),
        (9, 0), (9, 3), (9, 4), (9, 6), (9, 7), (9, 15), (9, 19), (9, 23), (9, 24)
    ) AS r(base_id, id_pais)
)
SELECT 
    p.ID_PROMOCION,
    r.id_pais
FROM RAW.PROMOCION p
JOIN REGLAS_GEOGRAFICAS r 
  ON MOD(p.ID_PROMOCION - 1, 9) + 1 = r.base_id; -- utilizamos este mod para volver ciclicamente a cada promoción, y asi ya tenemos cada promocion para cada pais por año

SELECT * FROM  RAW.PROMOCION_PAIS;
  
CREATE OR REPLACE TABLE CAMBIO (
    ID_PAIS INT,
    CODIGO_MONEDA VARCHAR(100),
    NOMBRE_MONEDA VARCHAR(100),
    FACTOR_USD NUMBER (38,2),
    CAMBIO_DESDE_USD NUMBER(38,2)); 



INSERT INTO RAW.CAMBIO (ID_PAIS, CODIGO_MONEDA, NOMBRE_MONEDA, FACTOR_USD, CAMBIO_DESDE_USD) VALUES 
(0,  'DZD', 'Dinar Argelino',        0.007463, 134.00),
(1,  'ARS', 'Peso Argentino',        0.001000, 1000.00),
(2,  'BRL', 'Real Brasileño',        0.181818, 5.50),
(3,  'CAD', 'Dólar Canadiense',      0.735294, 1.36),
(4,  'EGP', 'Libra Egipcia',         0.020833, 48.00),
(5,  'ETB', 'Birr Etíope',           0.008333, 120.00),
(6,  'EUR', 'Euro',                  1.086957, 0.92),
(7,  'EUR', 'Euro',                  1.086957, 0.92),
(8,  'INR', 'Rupia India',           0.011976, 83.50),
(9,  'IDR', 'Rupia Indonesia',       0.000065, 15500.00),
(10, 'IRR', 'Rial Iraní',            0.000024, 42000.00),
(11, 'IQD', 'Dinar Iraquí',          0.000763, 1310.00),
(12, 'JPY', 'Yen Japonés',           0.006897, 145.00),
(13, 'JOD', 'Dinar Jordano',         1.408451, 0.71),
(14, 'KES', 'Chelín Keniano',        0.007752, 129.00),
(15, 'MAD', 'Dirham Marroquí',       0.102041, 9.80),
(16, 'MZN', 'Metical Mozambiqueño',  0.015674, 63.80),
(17, 'PEN', 'Sol Peruano',           0.266667, 3.75),
(18, 'CNY', 'Yuan Chino',            0.140845, 7.10),
(19, 'RON', 'Leu Rumano',            0.219780, 4.55),
(20, 'SAR', 'Riyal Saudí',           0.266667, 3.75),
(21, 'VND', 'Dong Vietnamita',       0.000040, 24800.00),
(22, 'RUB', 'Rublo Ruso',            0.011111, 90.00),
(23, 'GBP', 'Libra Esterlina',       1.282051, 0.78),
(24, 'USD', 'Dólar Estadounidense',  1.00, 1.00);


UPDATE ORDERS SET O_ORDERDATE= DATEADD(SECOND, UNIFORM (0, 24+60*60 -1, RANDOM()), O_ORDERDATE);

ALTER TABLE NATION ADD COLUMN ZONA_HORARIA VARCHAR(50);

UPDATE NATION 
SET ZONA_HORARIA = CASE N_NATIONKEY
    WHEN 0  THEN 'Africa/Algiers'
    WHEN 1  THEN 'America/Argentina/Buenos_Aires'
    WHEN 2  THEN 'America/Sao_Paulo'
    WHEN 3  THEN 'America/Toronto'
    WHEN 4  THEN 'Africa/Cairo'
    WHEN 5  THEN 'Africa/Addis_Ababa'
    WHEN 6  THEN 'Europe/Paris'
    WHEN 7  THEN 'Europe/Berlin'
    WHEN 8  THEN 'Asia/Kolkata'
    WHEN 9  THEN 'Asia/Jakarta'
    WHEN 10 THEN 'Asia/Tehran'
    WHEN 11 THEN 'Asia/Baghdad'
    WHEN 12 THEN 'Asia/Tokyo'
    WHEN 13 THEN 'Asia/Amman'
    WHEN 14 THEN 'Africa/Nairobi'
    WHEN 15 THEN 'Africa/Casablanca'
    WHEN 16 THEN 'Africa/Maputo'
    WHEN 17 THEN 'America/Lima'
    WHEN 18 THEN 'Asia/Shanghai'
    WHEN 19 THEN 'Europe/Bucharest'
    WHEN 20 THEN 'Asia/Riyadh'
    WHEN 21 THEN 'Asia/Ho_Chi_Minh'
    WHEN 22 THEN 'Europe/Moscow'
    WHEN 23 THEN 'Europe/London'
    WHEN 24 THEN 'America/New_York'
    ELSE 'UTC'
END;
