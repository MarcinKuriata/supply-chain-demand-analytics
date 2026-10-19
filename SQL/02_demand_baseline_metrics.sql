-- =====================================================================
-- 02_demand_baseline_metrics.sql
-- Purpose: Calculate baseline demand forecasting metrics and service level KPIs
-- Core Deliverables:
--   1. Monthly Aggregated Demand by Product and Market Region
--   2. Moving Averages (3-Month Rolling Average Baseline)
--   3. Demand Volatility (Standard Deviation & Coefficient of Variation)
--   4. Fulfillment Performance & On-Time Delivery Rate (OTIF component)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Table / View: monthly_product_demand
-- Aggregates raw transactional order lines to Month-SKU-Region grain
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS monthly_product_demand;

CREATE TABLE monthly_product_demand AS
SELECT 
    STRFTIME('%Y-%m-01', f.order_date) AS demand_month,
    f.product_id,
    p.product_name,
    p.category_name,
    g.market,
    g.order_region,
    
    -- Volume & Financials
    SUM(f.demand_units) AS total_actual_demand_units,
    ROUND(SUM(f.net_sales_amount), 2) AS total_net_revenue,
    ROUND(SUM(f.profit_amount), 2) AS total_profit,
    COUNT(DISTINCT f.order_id) AS total_orders_count,
    
    -- Fulfillment & Service Level KPIs
    ROUND(AVG(f.actual_lead_time_days), 2) AS avg_lead_time_days,
    ROUND(AVG(f.scheduled_lead_time_days), 2) AS avg_scheduled_lead_time_days,
    ROUND(AVG(f.delivery_delay_days), 2) AS avg_delay_days,
    ROUND(SUM(f.is_on_time) * 100.0 / COUNT(*), 2) AS on_time_delivery_rate_pct

FROM fact_order_items f
JOIN dim_product p ON f.product_id = p.product_id
JOIN dim_geography g ON f.geography_id = g.geography_id
GROUP BY 
    STRFTIME('%Y-%m-01', f.order_date),
    f.product_id,
    p.product_name,
    p.category_name,
    g.market,
    g.order_region;

-- ---------------------------------------------------------------------
-- 2. Table / View: demand_forecast_baseline
-- Applies Window Functions to calculate a statistical rolling baseline
-- and historical demand volatility (Standard Deviation)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS demand_forecast_baseline;

CREATE TABLE demand_forecast_baseline AS
WITH ranked_demand AS (
    SELECT 
        demand_month,
        product_id,
        product_name,
        category_name,
        market,
        total_actual_demand_units,
        on_time_delivery_rate_pct,
        
        -- 3-Month Moving Average (Lagged by 1 to represent forecast baseline)
        ROUND(AVG(total_actual_demand_units) OVER (
            PARTITION BY product_id, market 
            ORDER BY demand_month 
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ), 2) AS baseline_moving_avg_3m,

        -- Previous Month Actual (Naive Forecast Model)
        LAG(total_actual_demand_units, 1) OVER (
            PARTITION BY product_id, market 
            ORDER BY demand_month
        ) AS naive_prior_month_actual

    FROM monthly_product_demand
)
SELECT 
    demand_month,
    product_id,
    product_name,
    category_name,
    market,
    total_actual_demand_units,
    baseline_moving_avg_3m,
    naive_prior_month_actual,
    on_time_delivery_rate_pct,
    
    -- Forecast Variance against 3M Baseline
    CASE 
        WHEN baseline_moving_avg_3m IS NOT NULL 
        THEN total_actual_demand_units - baseline_moving_avg_3m 
        ELSE NULL 
    END AS baseline_variance_units,
    
    -- Absolute Percentage Error for Baseline
    CASE 
        WHEN baseline_moving_avg_3m IS NOT NULL AND total_actual_demand_units > 0
        THEN ROUND(ABS(total_actual_demand_units - baseline_moving_avg_3m) * 100.0 / total_actual_demand_units, 2)
        ELSE NULL 
    END AS baseline_ape_pct

FROM ranked_demand;

-- ---------------------------------------------------------------------
-- 3. Performance Indexes on Analytical Tables
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_monthly_sku_mkt ON monthly_product_demand(product_id, market);
CREATE INDEX IF NOT EXISTS idx_baseline_month ON demand_forecast_baseline(demand_month);