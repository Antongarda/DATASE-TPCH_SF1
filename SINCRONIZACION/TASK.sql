USE SCHEMA PRACTICA_FINAL_NUEVA.STAGING;

CREATE OR REPLACE TASK STAGING.TSK_RAW_TO_STAGING
    WAREHOUSE=COMPUTE_WH
    SCHEDULE='1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW.STM_RAW_ORDERS')
    OR SYSTEM$STREAM_HAS_DATA('RAW.STM_RAW_LINEITEM')
    OR SYSTEM$STREAM_HAS_DATA('RAW.STM_RAW_CUSTOMER')

AS
BEGIN 

    INSERT INTO STAGING.STG_ORDERS
    SELECT * EXCLUDE (METADATA$ACTION, METADATA$ISUPDATE, METADAT$ROW_ID)
    FROM RAW.STM_RAW_ORDERS;

    INSERT INTO STAGING.STG_LINEITEM
    SELECT * EXCLUDE (METADATA$ACTION, METADATA$ISUPDATE, METADAT$ROW_ID)
    FROM RAW.STM_RAW_LINEITEM;

    MERGE INTO STAGING.STG_CUSTOMER t USING (
    SELECT *
    FROM RAW.STM_RAW_CUSTOMER
    WHERE METADATA$ACTION='INSERT') s
    ON t.c_custkey = s.c_custkey

    when matched then update set t.c_name = s.c_name , t.c_acctbal =s.c_acctbal, t.c_phone = s.c_phone
    when not matched then insert  (t.c_custkey, t.c_name, t.c_address,t.c_nationkey, t.c_phone, t.c_acctbal, t.c_mktsegment, t.c_comment) values (s.c_custkey, s.c_name, s.c_address,s.c_nationkey, s.c_phone, s.c_acctbal, s.c_mktsegment, s.c_comment);

END;

ALTER TASK STAGING.TSK_RAW_TO_STAGING RESUME;

ALTER TASK STAGING.TSK_RAW_TO_STAGING SUSPEND;



CREATE OR REPLACE TASK WAREHOUSE.TSK_STG_TO_WH
    WAREHOUSE=COMPUTE_WH
    SCHEDULE='1 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('STAGING.STM_STG_ORDERS')
    OR SYSTEM$STREAM_HAS_DATA('STAGING.STM_STG_LINEITEM')
    OR SYSTEM$STREAM_HAS_DATA('STAGING.STM_STG_CUSTOMER')

AS
BEGIN 

    MERGE INTO WAREHOUSE.DIM_CLIENTE t USING(
    SELECT *
    FROM STAGING.STM_STG_CUSTOMER 
    WHERE METADATA$ACTION='INSERT') s 
    ON t.client_id = s.c_custkey
    when matched then update set t.client_id = s.c_custkey , t.state_id = s.c_nationkey
    when not matched then insert (client_id, state_id) values (s.c_custkey, s.c_nationkey);

    
    MERGE INTO WAREHOUSE.FACT_LINEITEM trg USING(
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
    s.S_SUPPKEY AS store_id,
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
    LEFT JOIN STAGING.STG_SUPPLIER s ON l.L_SUPPKEY=s.S_SUPPKEY
    LEFT JOIN STAGING.STG_CUSTOMER c ON o.O_CUSTKEY=c.C_CUSTKEY
    LEFT JOIN STAGING.STG_PROMOCION_PAIS pp ON c.C_NATIONKEY= pp.ID_PAIS
    LEFT JOIN STAGING.STG_PROMOCION pr ON pp.ID_PROMOCION=pr.ID_PROMOCION AND o.O_ORDERDATE       BETWEEN PR.FECHA_INICIO AND pr.fecha_fin) src

    ON trg.order_id=src.order_id and trg.line_item_id= src.line_item_id

    when matched then update set 
        trg.quantity=src.quantity,
        trg.total_price=src.total_price,
        trg.unit_price= src.total_price,
        trg.discount=src.discount,
        trg.returned=src.returned,
        trg.tipo_operacion=src.tipo_operacion

    when not matched then insert (line_item_id, ship_priority, order_id, quantity, total_price, unit_price, discount, tax,returned, shipping_type, order_priority, product_id, store_id, client_id, promotion_id, commit_date, commmit_time, ship_date, ship_time, receipt_date,receipt_time, order_date, order_time) values (src.line_item_id, src.ship_priority, src.order_id, src.quantity, src.total_price, src.unit_price, src.discount, src.tax, src.returned, src.shipping_type, src.order_priority, src.product_id, src.store_id, src.client_id, src.promotion_id, src.commit_date, src.commmit_time, src.ship_date, src.ship_time, src.receipt_date, src.receipt_time, src.order_date, src.order_time);

END;

ALTER TASK WAREHOUSE.TSK_STG_TO_WH RESUME;

ALTER TASK WAREHOUSE.TSK_STG_TO_WH SUSPEND;