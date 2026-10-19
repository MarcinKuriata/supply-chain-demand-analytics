# End-to-End Supply Chain & Demand Planning Analytics

An enterprise-grade analytical portfolio project modeling, analyzing, and forecasting supply chain demand dynamics and fulfillment service levels (OTIF). Built using a lightweight Python ETL ingestion pipeline, relational SQL modeling (Star Schema) in SQLite, and executive visualization design.

---

## 🎯 Business Problem & Context

Global supply chains face the dual challenge of inventory cost optimization and service level maintenance:
1. Stockouts & Fulfillment Delays: Inaccurate demand visibility leads to shipment delays, compromised lead times, and drops in On-Time Delivery rates.
2. Excess Working Capital: Overestimating demand leads to surplus safety stocks, inflated holding costs, and capital lockup.

Project Objective:  
Ingest high-granularity operational data (180k+ transactions), structure it into an optimized relational Star Schema, establish baseline demand metrics via SQL window functions, and extract actionable business views for executive S&OP (Sales & Operations Planning) decision-making.

---

## 🏗️ Repository Architecture

supply-chain-demand-analytics/
|-- data/
|   |-- raw/                 # Local source datasets (excluded via .gitignore)
|   |-- processed/           # Optional CSV extracts for external reporting
|   `-- supply_chain.db      # SQLite relational database containing Star Schema & Views
|-- python/
|   |-- ingest_to_sql.py     # Clean ETL script loading raw CSV into SQL table
|   `-- run_sql.py           # SQL runner automating modular DDL and analytical execution
|-- SQL/
|   |-- 01_ddl_star_schema.sql         # Normalization into Fact and Dimension tables
|   |-- 02_demand_baseline_metrics.sql # Window functions, moving averages & volatility
|   `-- 03_business_views_kpi.sql      # ABC Pareto analysis, bottlenecks & executive KPIs
|-- visuals/                 # Dashboard prototypes, report exports, and architecture diagrams
|-- .gitignore               # Excludes large binaries (*.csv, *.db, *.pbix)
`-- README.md

---

## ⚙️ Technical Implementation & Workflow

### 1. Data Ingestion & Pipeline (Python ETL)
- Engine: Python (pandas, sqlite3).
- Data Source: DataCo Smart Supply Chain Dataset (~180,519 rows, 53 raw attributes).
- Transformation: Handled encoding edge-cases (ISO-8859-1), standardized column headers to snake_case, and ingested raw data directly into local SQLite database (supply_chain.db).

### 2. Relational Data Modeling (SQL DDL - Star Schema)
- Dimension Tables:
  - dim_product: Deduplicated catalog with product IDs, names, categories, and standard pricing.
  - dim_customer: Customer segments (Consumer, Corporate, Home Office) and geographic metadata.
  - dim_geography: Destination hierarchy across global markets, regions, and delivery cities.
- Fact Table:
  - fact_order_items: Order-line grain containing demand volumes, net financials, actual vs. scheduled lead times, delivery_delay_days, and zero-delay flags (is_on_time).
- Performance Optimization: Integrated B-Tree indexes across primary foreign keys (idx_fact_product, idx_fact_date, idx_fact_geography, idx_fact_customer).

### 3. Demand Baseline & Metrics Formulation (SQL Analytical Layer)
- Grain Aggregation: Rolled up transactional lines to a clean Month-SKU-Region analytical baseline (monthly_product_demand).
- Window Functions: Implemented a 3-month trailing moving average (ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) to eliminate look-ahead bias and calculate statistical variance.
- Fulfillment KPIs: Quantified On-Time Delivery percentage linked directly to product demand.

### 4. Executive Business Views
- view_abc_product_segmentation: Cumulative running sum calculation segmenting products into:
  - Class A: Top 80% volume drivers (core revenue generators).
  - Class B: Middle 15% demand contributors.
  - Class C: Long-tail 5% low-velocity inventory.
- view_fulfillment_bottlenecks: Identifies delivery delays and financial impact across regional shipping modes.
- view_executive_monthly_summary: Consolidated high-level monthly dashboard table linking total demand, revenue, profit, and OTIF rates.

---

## 📊 Core Supply Chain Formulas

- Forecast Variance: Actual Demand - Baseline Forecast
- On-Time Delivery Rate: (Sum of On-Time Deliveries / Total Shipments) * 100
- Cumulative Pareto Contribution: (Running Total Demand / Grand Total Demand) * 100

---

## 🚀 Execution & Reproducibility

1. Clone repository:
   git clone https://github.com/<your-username>/supply-chain-demand-analytics.git
   cd supply-chain-demand-analytics

2. Install dependencies:
   python -m pip install pandas

3. Download dataset: Place DataCoSupplyChainDataset.csv into data/raw/.

4. Run ingestion pipeline:
   python python/ingest_to_sql.py

5. Execute SQL analytics: Execute files 01, 02, and 03 via python/run_sql.py or inspect directly using SQLite Viewer.
