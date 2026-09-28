USE DATABASE PRACTICA_FINAL_NUEVA;

CREATE SCHEMA IF NOT EXISTS ANALYTICS;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE VIEW ANALYTICS.ANALISIS_TIENDA AS
SELECT 
    s.name as store_name,
    li.store_id as store_id,
    st.name as state,
    SUM(li.quantity) as sum_unidades,
    SUM(li.total_price) as importe

FROM WAREHOUSE.FACT_LINEITEM li
LEFT JOIN WAREHOUSE.DIM_STORE s ON li.store_id=s.store_id
LEFT JOIN WAREHOUSE.DIM_STATE st ON s.state_id=st.state_id
GROUP BY 1,2,3
ORDER BY importe DESC;

SELECT * FROM ANALYTICS.ANALISIS_TIENDA;

CREATE OR REPLACE VIEW ANALYTICS.ANALISIS_DEV_PRODUCTO AS
WITH productos_devueltos AS (
    select 
    store_id,
    COUNT(product_id) as productos_totales,
    COUNT( CASE WHEN TIPO_OPERACION='DEVOLUCION' THEN 1 END) as prod_dev
    from warehouse.fact_lineitem 
    GROUP BY 1
)
SELECT
    s.name as store_name,
    d.store_id as store_id,
    st.name as state,
    ROUND((d.prod_dev/d.productos_totales)*100, 2) as pct_productos_devueltos

FROM productos_devueltos d
LEFT JOIN WAREHOUSE.DIM_STORE s ON d.store_id=s.store_id
LEFT JOIN WAREHOUSE.DIM_STATE st ON s.state_id=st.state_id;

SELECT * FROM ANALYTICS.ANALISIS_DEV_PRODUCTO;


CREATE OR REPLACE VIEW ANALYTICS.ANALISIS_DEV_TIENDA AS
WITH productos_devueltos AS (
    select 
    product_id,
    COUNT(*) as total_lineas,
    COUNT( CASE WHEN TIPO_OPERACION='DEVOLUCION' THEN 1 END) as lin_dev
    from warehouse.fact_lineitem 
    GROUP BY 1
)
SELECT
    d.product_id as product_id,
    p.name as product_name,
    d.total_lineas,
    d.lin_dev,
    ROUND((d.lin_dev/d.total_lineas)*100, 2) as pct_productos_devueltos
FROM productos_devueltos d
JOIN warehouse.dim_product p ON d.product_id=p.product_id
order by pct_productos_devueltos desc;

SELECT * FROM ANALYTICS.ANALISIS_DEV_TIENDA;



CREATE OR REPLACE VIEW ANALYTICS.ANALISIS_PROMOCIONES AS
SELECT 
    l.PROMOTION_ID as promotion_id,
    p.name as promotion_name, 
    p.nation_id as nation_id,
    n.name as nation,
    ca.code as codigo_moneda,
    SUM(l.quantity) as prod_vend,
    SUM(l.total_price) as importe_generado,
    SUM(ca.usd_ratio *l.total_price) as importe_local
    
FROM WAREHOUSE.FACT_LINEITEM l 
LEFT JOIN WAREHOUSE.DIM_PROMOTION p ON l.promotion_id=p.promotion_id
LEFT JOIN warehouse.dim_nation n ON p.nation_id=n.nation_id 
LEFT JOIN warehouse.dim_currency ca ON n.currency_id=ca.currency_id
where l.tipo_operacion='VENTA' and l.promotion_id IS NOT NULL
GROUP BY 1,2,3,4,5
order by 6 desc;

select * from analytics.analisis_promociones;



CREATE OR REPLACE VIEW ANALYTICs.ANALISIS_TEMP AS 
with ventas_diarias as(
    select
        d.year as ano,
        d.month as mes,
        d.day as dia,
        d.date_id,
        SUM(l.quantity) as ventas_dia,
        SUM(l.total_price) as importe_dia
    FROM warehouse.dim_date d 
    LEFT JOIN warehouse.fact_lineitem l on d.date_id=l.order_date
    group by d.year, d.month, d.day, d.date_id
)
SELECT 
    ano,
    mes,
    dia,
    ventas_dia,
    importe_dia,
    SUM(ventas_dia) over (partition by ano, mes order by dia) as ventas_mes,
    SUM(ventas_dia) over (partition by ano, mes ) as ventas_mes_total,
    SUM(importe_dia) OVER (partition by ano, mes order by dia) as importe_mes,
    SUM(importe_dia) OVER (partition by ano, mes ) as importe_mes_total,
    SUM(ventas_dia) OVER (partition by ano order by mes, dia) as ventas_ano,
    SUM(ventas_dia) OVER (partition by ano ) as ventas_ano_total,
    sum(importe_dia) over (partition by ano order by mes, dia) as importe_ano,
    sum(importe_dia) over (partition by ano ) as importe_ano_total

from ventas_diarias
order by ano, mes, dia;



select * from analytics.analisis_temp;


CREATE OR REPLACE VIEW ANALYTICS.ANALISIS_VOLUMEN_PROD as
SELECT
p.product_id as product_id,
p.name as name,
SUM(l.quantity) as unidades_vendidas,
SUM(l.total_price) as importe_total,
FROM warehouse.fact_lineitem l
JOIN warehouse.dim_product p ON l.product_id=p.product_id
GROUP BY 1,2
ORDER BY 2 desc
LIMIT 20;

select * from analytics.analisis_volumen_prod;

