# End-to-End Business Intelligence & Data Warehousing Project

## Project Overview

This repository demonstrates a complete, industry-standard Business Intelligence (BI) and Data Engineering solution. The project covers the entire data lifecycle — from raw data ingestion and anomaly cleaning to relational Data Warehouse modeling, Slowly Changing Dimensions (SCD Type 2), and high-performance analytical dashboarding in Power BI.

The architecture follows a rigorous multi-layer approach (`Stage` -> `Core` -> `Mart`), ensuring absolute data integrity, historical traceability of customer segments, and clean visual storytelling for business stakeholders.

---

## Project Structure & File Descriptions

The project is structured into three consecutive evolutionary stages, separating raw data, transformation scripts, architectural diagrams, and analytical dashboards:

### 📁 Stage 1 — Data Ingestion & Exploratory Data Analysis (EDA)
Focuses on profiling raw datasets, identifying data quality anomalies, handling missing values, and performing initial exploratory checks.

| File / Path | Description |
| :--- | :--- |
| `Stage 1 - Ingestion & EDA/data/dirty_financial_transactions.csv` | Raw transactional dataset containing data quality anomalies and missing values. |
| `Stage 1 - Ingestion & EDA/data/cleaned_financial_transactions.csv` | Cleaned and processed transaction records prepared for downstream loading. |
| `Stage 1 - Ingestion & EDA/data/dim_customer_rfm.csv` | Customer's RFM (Recency, Frequency, Monetary) segmentation file. |
| `Stage 1 - Ingestion & EDA/scripts/stage_1.ipynb` | Jupyter Notebook containing data profiling, validation logic, and cleaning steps. |
| `Stage 1 - Ingestion & EDA/eda_report.html` | Automated exploratory data analysis profiling report. |

### 📁 Stage 2 — Data Warehouse Architecture & ETL Pipeline
Covers database schema deployment, staging transformations, relational modeling, and historical tracking implementation.

| File / Path | Description |
| :--- | :--- |
| `Stage 2 - Data Warehouse & ETL/data/initial_load.csv` | Baseline snapshot dataset used for initial database population. |
| `Stage 2 - Data Warehouse & ETL/data/delta_load.csv` | Incremental data updates designed to test pipeline flexibility and delta loading. |
| `Stage 2 - Data Warehouse & ETL/data/dim_customer_rfm.csv` | Processed customer dimension dataset mapped for historical tracking. |
| `Stage 2 - Data Warehouse & ETL/data/dirty_financial_transactions.csv` | Backup copy of raw transactions referenced during pipeline stress-testing. |
| `Stage 2 - Data Warehouse & ETL/scripts/ETL_pipeline.sql` | Core SQL script creating database schemas (`stage`, `core`, `mart`), tables, constraints, and ETL data flows. |
| `Stage 2 - Data Warehouse & ETL/scripts/stage_2.ipynb` | Jupyter Notebook automating pipeline execution and verifying transformation logic. |
| `Stage 2 - Data Warehouse & ETL/diagrams/ERD.pdf` | Entity-Relationship Diagram outlining the relational Data Warehouse schema. |
| `Stage 2 - Data Warehouse & ETL/diagrams/DFD.jpg` | Data Flow Diagram illustrating architectural layers and data movement. |

### 📁 Stage 3 — Analytics, Reporting & Quality Assurance
Implements the Business Intelligence presentation layer, documentation, business requirements, and validation checks.

| File / Path | Description |
| :--- | :--- |
| `Stage 3 - Analytics & BI/dashboards/Customer_Lifecycle_Operations_Dashboard.pbix` | Final interactive Power BI dashboard containing strategic and operational views. |
| `Stage 3 - Analytics & BI/dashboards/Mockups.pdf` | UI/UX visual layout wireframes and dashboard design mockups. |
| `Stage 3 - Analytics & BI/docs/RGCS_BRD.txt` | Business Requirements Document (BRD) defining project scope, metrics, and KPI formulas. |
| `Stage 3 - Analytics & BI/docs/Data Storytelling_Speech.txt` | Structured presentation script and storytelling report for defending project findings. |
| `Stage 3 - Analytics & BI/validation/data_validation.sql` | SQL queries utilized to cross-check database calculation aggregates against Power BI visuals. |
| `Stage 3 - Analytics & BI/validation/at_risk_customers_validation.png` | Visual QA verification screenshot for At-Risk customer segment counts. |
| `Stage 3 - Analytics & BI/validation/average_order_value_validation.png` | Visual QA verification screenshot for Average Order Value (AOV) metrics. |
| `Stage 3 - Analytics & BI/validation/total_revenue_validation.png` | Visual QA verification screenshot confirming Total Revenue calculations. |

---

## Key Technical Features

* **Multi-Layer DWH Architecture:** Clean separation of concerns through Staging, Core (Data Warehouse), and Mart schemas in PostgreSQL.
* **SCD Type 2 Implementation:** Historical tracking of customer segments (`dim_customer_rfm`) to ensure complete analytical integrity for past periods.
* **Advanced Data Cleaning:** Robust handling of `NULL` values, deduplication, string trimming, and outlier imputations via Python and SQL.
* **Professional Power BI Modeling:** Optimized star-schema semantic model featuring DAX measures (`Total Revenue`, `Total Orders`, `AOV`) and secondary Y-axis percentage trendlines (QoQ Growth).

---

## How to Reproduce the Project

1. **Database Deployment:** 
   Set up a PostgreSQL database and execute the schema creation and ETL scripts found in `Stage 2 - Data Warehouse & ETL/scripts/Script_etl.sql`.
2. **Pipeline Execution:** 
   Run the data profiling and delta-loading workflows via the Jupyter notebooks located in `Stage 1` and `Stage 2` scripts directories.
3. **Dashboard Exploration:** 
   Open `Stage 3 - Analytics & BI/dashboards/Customer_Lifecycle_Operations_Dashboard.pbix` in Power BI Desktop to interact with the reporting model.

---

## Technologies Used

* **Database & SQL:** PostgreSQL, relational design, constraints, window functions, SCD logic.
* **Data Engineering:** Python, Pandas, Jupyter Notebooks.
* **Business Intelligence:** Power BI, DAX, data modeling.
* **Version Control:** Git & GitHub.

---
## Dataset:

https://www.kaggle.com/datasets/alfarisbachmid/dirty-financial-transactions-dataset
