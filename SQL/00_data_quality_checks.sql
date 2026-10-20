-- =====================================================================
-- 00_data_quality_checks.sql
-- Purpose: Audit data integrity, missing values, duplicates, and business logic
-- Expected Outcome: All checks should return 0 failed records
-- =====================================================================

-- ---------------------------------------------------------------------
-- Check 1: Primary Key Uniqueness in Fact Table
-- ---------------------------------------------------------------------
SELECT 
    'Duplicate Order Item IDs' AS check_name,
    COUNT(*) - COUNT(DISTINCT order_item_id) AS failed_records_count
FROM fact_order_items;

-- ---------------------------------------------------------------------
-- Check 2: Referential Integrity (Orphan Foreign Keys)
-- ---------------------------------------------------------------------
SELECT 
    'Orphan Product IDs' AS check_name,
    COUNT(*) AS failed_records_count
FROM fact_order_items f
LEFT JOIN dim_product p ON f.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT 
    'Orphan Geography IDs' AS check_name,
    COUNT(*) AS failed_records_count
FROM fact_order_items f
LEFT JOIN dim_geography g ON f.geography_id = g.geography_id
WHERE g.geography_id IS NULL;

-- ---------------------------------------------------------------------
-- Check 3: Business Logic & Negative Values
-- ---------------------------------------------------------------------
SELECT 
    'Non-positive Demand Quantities' AS check_name,
    COUNT(*) AS failed_records_count
FROM fact_order_items
WHERE demand_units <= 0

UNION ALL

SELECT 
    'Invalid Delivery Dates (Shipped before Order)' AS check_name,
    COUNT(*) AS failed_records_count
FROM fact_order_items
WHERE shipping_date < order_date;