-- =====================================================================
-- 01_ddl_star_schema.sql
-- Purpose: Transform flat raw dataset into an optimized Star Schema
-- Target Model:
--   - dim_product (Product catalog & pricing metadata)
--   - dim_customer (Customer demographics & segmentation)
--   - dim_geography (Destination markets & regional grouping)
--   - fact_order_items (Order line items, demand volumes & fulfillment metrics)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Dimension: dim_product
-- Deduplicated product dimension capturing pricing and categories
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_product;

CREATE TABLE dim_product AS
SELECT 
    product_card_id AS product_id,
    TRIM(product_name) AS product_name,
    category_id,
    TRIM(category_name) AS category_name,
    department_id,
    TRIM(department_name) AS department_name,
    ROUND(CAST(product_price AS REAL), 2) AS standard_unit_price
FROM raw_supply_chain_data
GROUP BY product_card_id;

-- ---------------------------------------------------------------------
-- 2. Dimension: dim_customer
-- Customer profiles and market segment mapping
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_customer;

CREATE TABLE dim_customer AS
SELECT 
    customer_id,
    TRIM(customer_segment) AS customer_segment,
    TRIM(customer_city) AS customer_city,
    TRIM(customer_state) AS customer_state,
    TRIM(customer_country) AS customer_country
FROM raw_supply_chain_data
GROUP BY customer_id;

-- ---------------------------------------------------------------------
-- 3. Dimension: dim_geography
-- Order delivery destinations to analyze regional EMEA/Global demand
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_geography;

CREATE TABLE dim_geography AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY order_region, order_country, order_city) AS geography_id,
    TRIM(order_region) AS order_region,
    TRIM(order_country) AS order_country,
    TRIM(order_city) AS order_city,
    TRIM(market) AS market
FROM raw_supply_chain_data
GROUP BY order_region, order_country, order_city, market;

-- ---------------------------------------------------------------------
-- 4. Fact Table: fact_order_items
-- Granularity: One row per order item line
-- Includes demand quantities, financial performance, and delivery metrics (OTIF)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fact_order_items;

CREATE TABLE fact_order_items AS
SELECT 
    r.order_id,
    r.order_item_id,
    r.product_card_id AS product_id,
    r.customer_id,
    g.geography_id,
    
    -- Temporal attributes parsed to standard ISO format
    DATE(SUBSTR(r.order_date_dateorders, 1, 10)) AS order_date,
    DATE(SUBSTR(r.shipping_date_dateorders, 1, 10)) AS shipping_date,
    
    -- Demand & financial metrics
    CAST(r.order_item_quantity AS INTEGER) AS demand_units,
    ROUND(CAST(r.sales AS REAL), 2) AS gross_sales_amount,
    ROUND(CAST(r.order_item_total AS REAL), 2) AS net_sales_amount,
    ROUND(CAST(r.order_item_discount AS REAL), 2) AS discount_amount,
    ROUND(CAST(r.order_profit_per_order AS REAL), 2) AS profit_amount,
    
    -- Operational & fulfillment service level (OTIF foundation)
    CAST(r.days_for_shipping_real AS INTEGER) AS actual_lead_time_days,
    CAST(r.days_for_shipment_scheduled AS INTEGER) AS scheduled_lead_time_days,
    (CAST(r.days_for_shipping_real AS INTEGER) - CAST(r.days_for_shipment_scheduled AS INTEGER)) AS delivery_delay_days,
    CASE 
        WHEN CAST(r.days_for_shipping_real AS INTEGER) <= CAST(r.days_for_shipment_scheduled AS INTEGER) THEN 1 
        ELSE 0 
    END AS is_on_time,
    
    TRIM(r.delivery_status) AS delivery_status,
    CAST(r.late_delivery_risk AS INTEGER) AS late_risk_flag,
    TRIM(r.shipping_mode) AS shipping_mode,
    TRIM(r.order_status) AS order_status

FROM raw_supply_chain_data r
JOIN dim_geography g 
    ON TRIM(r.order_region) = g.order_region 
   AND TRIM(r.order_country) = g.order_country 
   AND TRIM(r.order_city) = g.order_city
   AND TRIM(r.market) = g.market;

-- ---------------------------------------------------------------------
-- 5. Performance Indexes
-- Optimize query performance for BI and analytical queries
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_fact_product ON fact_order_items(product_id);
CREATE INDEX IF NOT EXISTS idx_fact_date ON fact_order_items(order_date);
CREATE INDEX IF NOT EXISTS idx_fact_geography ON fact_order_items(geography_id);
CREATE INDEX IF NOT EXISTS idx_fact_customer ON fact_order_items(customer_id);