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
SELECT DISTINCT
    order_item_cardprod_id AS product_id,
    product_name,
    category_name,
    department_name,
    product_price AS standard_unit_price
FROM raw_supply_chain_data;

-- ---------------------------------------------------------------------
-- 2. Dimension: dim_customer
-- Customer profiles and market segment mapping
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_customer;

CREATE TABLE dim_customer AS
SELECT DISTINCT
    order_customer_id AS customer_id,
    customer_segment,
    customer_city,
    customer_state,
    customer_country
FROM raw_supply_chain_data;

-- ---------------------------------------------------------------------
-- 3. Dimension: dim_geography
-- Order delivery destinations to analyze regional EMEA/Global demand
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dim_geography;

CREATE TABLE dim_geography AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY market, order_region, order_country, order_city) AS geography_id,
    market,
    order_region,
    order_country,
    order_city,
    order_state
FROM (
    SELECT DISTINCT
        market,
        order_region,
        order_country,
        order_city,
        order_state
    FROM raw_supply_chain_data
);

-- ---------------------------------------------------------------------
-- 4. Fact Table: fact_order_items
-- Granularity: One row per order item line
-- Includes demand quantities, financial performance, and delivery metrics (OTIF)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS fact_order_items;

CREATE TABLE fact_order_items AS
SELECT 
    r.order_item_id,
    r.order_id,
    r.order_item_cardprod_id AS product_id,
    r.order_customer_id AS customer_id,
    g.geography_id,
    r.order_date_dateorders AS order_date,
    r.shipping_date_dateorders AS shipping_date,
    r.order_item_quantity AS demand_units,
    (r.order_item_product_price * r.order_item_quantity) AS gross_sales_amount,
    r.sales AS net_sales_amount,
    r.order_item_discount AS discount_amount,
    r.order_profit_per_order AS profit_amount,
    r.days_for_shipping_real AS actual_lead_time_days,
    r.days_for_shipment_scheduled AS scheduled_lead_time_days,
    (r.days_for_shipping_real - r.days_for_shipment_scheduled) AS delivery_delay_days,
    CASE 
        WHEN r.days_for_shipping_real <= r.days_for_shipment_scheduled THEN 1 
        ELSE 0 
    END AS is_on_time,
    r.delivery_status,
    r.late_delivery_risk AS late_risk_flag,
    r.shipping_mode,
    r.order_status
FROM raw_supply_chain_data r
JOIN dim_geography g 
    ON r.market = g.market
    AND r.order_region = g.order_region
    AND r.order_country = g.order_country
    AND r.order_city = g.order_city
    AND r.order_state = g.order_state;

-- ---------------------------------------------------------------------
-- 5. Performance Indexes
-- Optimize query performance for BI and analytical queries
-- ---------------------------------------------------------------------
CREATE INDEX idx_fact_product ON fact_order_items (product_id);
CREATE INDEX idx_fact_customer ON fact_order_items (customer_id);
CREATE INDEX idx_fact_geography ON fact_order_items (geography_id);
CREATE INDEX idx_fact_order_date ON fact_order_items (order_date);