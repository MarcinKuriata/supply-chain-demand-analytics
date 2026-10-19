-- =====================================================================
-- 03_business_views_kpi.sql
-- Purpose: Final analytical views for BI reporting and S&OP decisions
-- Core Views:
--   1. view_abc_product_segmentation (Pareto analysis on total demand volume)
--   2. view_fulfillment_bottlenecks (Delay analysis by market and shipping mode)
--   3. view_executive_monthly_summary (High-level monthly performance KPIs)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. View: view_abc_product_segmentation
-- Segment products into A (Top 80%), B (Next 15%), and C (Tail 5%)
-- based on cumulative demand contribution
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS view_abc_product_segmentation;

CREATE VIEW view_abc_product_segmentation AS
WITH product_totals AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category_name,
        p.department_name,
        SUM(f.demand_units) AS total_units_demanded,
        ROUND(SUM(f.net_sales_amount), 2) AS total_net_revenue,
        ROUND(SUM(f.profit_amount), 2) AS total_profit
    FROM dim_product p
    JOIN fact_order_items f ON p.product_id = f.product_id
    GROUP BY p.product_id, p.product_name, p.category_name, p.department_name
),
cumulative_shares AS (
    SELECT 
        *,
        SUM(total_units_demanded) OVER () AS grand_total_units,
        SUM(total_units_demanded) OVER (
            ORDER BY total_units_demanded DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_total_units
    FROM product_totals
)
SELECT 
    product_id,
    product_name,
    category_name,
    department_name,
    total_units_demanded,
    total_net_revenue,
    total_profit,
    ROUND(running_total_units * 100.0 / grand_total_units, 2) AS cumulative_demand_pct,
    CASE 
        WHEN running_total_units * 1.0 / grand_total_units <= 0.80 THEN 'A - Core (80%)'
        WHEN running_total_units * 1.0 / grand_total_units <= 0.95 THEN 'B - Medium (15%)'
        ELSE 'C - Long Tail (5%)'
    END AS abc_class
FROM cumulative_shares;

-- ---------------------------------------------------------------------
-- 2. View: view_fulfillment_bottlenecks
-- Highlights fulfillment inefficiencies, delivery delays, and service level drops
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS view_fulfillment_bottlenecks;

CREATE VIEW view_fulfillment_bottlenecks AS
SELECT 
    g.market,
    g.order_region,
    f.shipping_mode,
    COUNT(f.order_item_id) AS total_shipments,
    SUM(f.is_on_time) AS on_time_shipments,
    ROUND(SUM(f.is_on_time) * 100.0 / COUNT(*), 2) AS on_time_rate_pct,
    ROUND(AVG(f.actual_lead_time_days), 2) AS avg_actual_lead_time,
    ROUND(AVG(f.scheduled_lead_time_days), 2) AS avg_scheduled_lead_time,
    ROUND(AVG(f.delivery_delay_days), 2) AS avg_delay_days,
    SUM(CASE WHEN f.late_risk_flag = 1 THEN 1 ELSE 0 END) AS late_risk_orders_count,
    ROUND(SUM(f.net_sales_amount), 2) AS total_affected_revenue
FROM fact_order_items f
JOIN dim_geography g ON f.geography_id = g.geography_id
GROUP BY g.market, g.order_region, f.shipping_mode;

-- ---------------------------------------------------------------------
-- 3. View: view_executive_monthly_summary
-- Executive S&OP summary blending demand volumes, financials, and OTIF service level
-- ---------------------------------------------------------------------
DROP VIEW IF EXISTS view_executive_monthly_summary;

CREATE VIEW view_executive_monthly_summary AS
SELECT 
    demand_month,
    COUNT(DISTINCT product_id) AS active_skus_count,
    SUM(total_actual_demand_units) AS total_monthly_demand,
    ROUND(SUM(total_net_revenue), 2) AS total_monthly_revenue,
    ROUND(SUM(total_profit), 2) AS total_monthly_profit,
    ROUND(AVG(on_time_delivery_rate_pct), 2) AS monthly_otif_rate_pct
FROM monthly_product_demand
GROUP BY demand_month
ORDER BY demand_month ASC;