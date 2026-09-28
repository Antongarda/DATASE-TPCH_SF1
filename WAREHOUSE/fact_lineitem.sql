CREATE SCHEMA IF NOT EXISTS PRACTICA_FINAL_NUEVA.WAREHOUSE;
USE SCHEMA PRACTICA_FINAL_NUEVA.WAREHOUSE;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_PRODUCT AS 
SELECT 
    p.P_PARTKEY as product_id,
    p.P_NAME AS name, 
    p.P_MFGR as manufacturer,
    p.P_BRAND as brand,
    p.P_RETAILPRICE AS retail_price,
FROM STAGING.STG_PART p ;

select * from dim_product;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_SUPPLIER AS 
SELECT 
    s.S_SUPPKEY AS supplier_id,
    s.S_NAME as name,
    s.S_NATIONKEY as nation_id,
FROM STAGING.STG_SUPPLIER s ;

CREATE OR REPLACE TABLE WAREHOUSE.DIM_NATION as 
SELECT
    n.N_NATIONKEY as nation_id,
    n.N_NAME as name,
    ca.ID_PAIS as currency_id,
    CASE 
        WHEN r.R_NAME ='MIDDLE EAST' THEN 'ASIA' 
        ELSE r.R_NAME
    END as CONTINENT,
    r.R_NAME as region,
FROM STAGING.STG_NATION n 
LEFT JOIN STAGING.STG_CAMBIO ca ON n.n_nationkey= ca.id_pais
LEFT JOIN staging.stg_region r  ON n.n_regionkey= r.r_regionkey;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_CURRENCY as
SELECT
    ca.id_pais as currency_id,
    ca.codigo_moneda as code,
    '2026-09-23'::DATE as date,
    ca.cambio_desde_usd as usd_ratio
FROM staging.stg_cambio ca ;

CREATE OR REPLACE TABLE WAREHOUSE.DIM_STATE AS
SELECT 
    N_NATIONKEY as state_id,
    N_NAME as name,
    N_NATIONKEY as nation_id,
    ZONA_HORARIA as timezone
FROM STAGING.STG_NATION;

CREATE OR REPLACE TABLE WAREHOUSE.DIM_CLIENT AS 
SELECT 
    c.C_CUSTKEY as client_id,
    n.N_NATIONKEY as state_id
FROM STAGING.STG_CUSTOMER c
LEFT JOIN STAGING.STG_NATION n ON c.c_nationkey= n.n_nationkey;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_STORE AS
SELECT 
    t.ID_TIENDA as store_id,
    nombre_tienda as name,
    t.ID_PAIS as state_id
FROM staging.stg_tienda t ;


select * from warehouse.dim_store;

CREATE OR REPLACE TABLE WAREHOUSE.DIM_PROMOTION AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY pr.ID_PROMOCION, pp.ID_PAIS) AS  promotion_id,
    pr.nombre_promocion as name,
    TO_CHAR (pr.fecha_inicio, 'YYYYMMDD')::INT as start_date,
    0000 as start_time,
    TO_CHAR(pr.fecha_fin, 'YYYYMMDD')::INT as end_date,
    2359 as end_time,
    pp.ID_PAIS AS nation_id,
    pr.DESCUENTO AS DESCUENTO_pct

FROM STAGING.STG_PROMOCION pr
JOIN STAGING.STG_PROMOCION_PAIS PP ON pr.id_promocion=pp.id_promocion;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_DATE AS
WITH GENERADOR_FECHAS AS (
    SELECT DATEADD(day, SEQ4(), '1992-01-01'::DATE) as fecha 
    FROM TABLE(GENERATOR(ROWCOUNT =>2950))
)
SELECT 
    TO_CHAR (fecha, 'YYYYMMDD')::INT as date_id,
    DAY(fecha) as day,
    MONTH(fecha) as month,
    YEAR(fecha) as year,
    DAYNAME(fecha) as week_day 
FROM GENERADOR_FECHAS
WHERE fecha <= '1998-12-31'::DATE;


CREATE OR REPLACE TABLE WAREHOUSE.DIM_TIME AS 
WITH GENERADOR_TIEMPO AS (
    SELECT TIMEADD(MINUTE, SEQ4(), '00:00:00'::TIME) AS tiempo
    from table(generator(rowcount=>1440)))
select 
    to_char(tiempo, 'HH24MI')::INT as time_id,
    MINUTE(tiempo) as minute,
    HOUR(tiempo) as hour 
FROM generador_tiempo;

 -- SEQ4() Genera una secuencia de enteros consecutiva que empieza en cero


CREATE OR REPLACE TABLE WAREHOUSE.FACT_LINEITEM AS 
SELECT 
    ROW_NUMBER() OVER (ORDER BY l.L_ORDERKEY, l.l_linenumber) AS line_item_id,
    o.O_SHIPPRIORITY AS ship_priority,
    o.O_ORDERKEY AS order_id,
    l.L_QUANTITY as quantity,
    o.O_TOTALPRICE as total_price,
    ROUND ( l.L_EXTENDEDPRICE /l.L_QUANTITY , 2 ) as unit_price,
    l.L_DISCOUNT AS discount, 
    l.L_tax as tax,
    l.L_RETURNFLAG AS returned,
     CASE 
        WHEN l.L_RETURNFLAG='R' THEN 'DEVOLUCION'
        ELSE 'VENTA'
    END as TIPO_OPERACION,
    
    CASE  
        WHEN DATEDIFF('day', l.L_COMMITDATE, l.L_RECEIPTDATE) > 10 THEN 0
        WHEN l.L_RECEIPTDATE<=l.L_COMMITDATE THEN 1
        WHEN DATEDIFF('day', l.L_COMMITDATE, l.L_RECEIPTDATE) BETWEEN 1 AND 10 THEN 2
    END AS ID_PLAZO_ENTREGA,

    CASE  
        WHEN DATEDIFF('day', l.L_COMMITDATE, l.L_RECEIPTDATE) > 10 THEN 'Fuera de plazo, el pedido se ha entregado con un retraso mayor a 10 días'
        WHEN l.L_RECEIPTDATE<=l.L_COMMITDATE THEN 'En plazo, el pedido se ha entregado como muy tarde en la fecha estimada 
(COMMITDATE)'
        WHEN DATEDIFF('day', l.L_COMMITDATE, l.L_RECEIPTDATE) BETWEEN 1 AND 10 THEN 'Entrega tardía, el pedido se ha entregado como muy tarde 10 días después de la fecha estimada'

    END AS DESCRIPCION,

    l.L_SHIPMODE AS shipping_type,
    o.O_ORDERPRIORITY AS order_priority,
    p.P_PARTKEY as product_id,
    t.ID_TIENDA AS store_id,
    c.C_CUSTKEY as client_id,
    pr.ID_PROMOCION AS  promotion_id,
    
    TO_CHAR(l.L_COMMITDATE,'YYYYMMDD')::INT as commit_date,
    0000 as commit_time,
    TO_CHAR(l.L_SHIPDATE, 'YYYYMMDD')::INT as ship_date,
    0000 as ship_time,
    TO_CHAR(l.L_RECEIPTDATE, 'YYYYMMDD')::INT as receipt_date,
    0000 as receipt_time,
    TO_CHAR(o.O_ORDERDATE, 'YYYYMMDD')::INT AS order_date,
    0000 as order_time

FROM STAGING.STG_LINEITEM l 
LEFT JOIN STAGING.STG_ORDERS o ON l.L_ORDERKEY=o.O_ORDERKEY
LEFT JOIN STAGING.STG_PART p ON l.L_PARTKEY=p.P_PARTKEY
LEFT JOIN STAGING.STG_TIENDA t ON o.id_tienda=t.id_tienda
LEFT JOIN STAGING.STG_CUSTOMER c ON o.O_CUSTKEY=c.C_CUSTKEY
LEFT JOIN STAGING.STG_PROMOCION_PAIS pp ON c.C_NATIONKEY= pp.ID_PAIS
LEFT JOIN STAGING.STG_PROMOCION pr ON pp.ID_PROMOCION=pr.ID_PROMOCION AND o.O_ORDERDATE BETWEEN PR.FECHA_INICIO AND pr.fecha_fin;

 
  
    
    
