DROP SCHEMA IF EXISTS stage CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS mart CASCADE;
 
CREATE SCHEMA stage;
CREATE SCHEMA core;
CREATE SCHEMA mart;

DROP TABLE IF EXISTS temp_prepared_facts;

DROP TABLE IF EXISTS stage.raw_transactions CASCADE;


/*STAGE*/

CREATE TABLE stage.raw_transactions (
    transaction_id VARCHAR(100),
    transaction_date VARCHAR(50),
    customer_id VARCHAR(100),
    product_name VARCHAR(255),
    quantity VARCHAR(50),
    price VARCHAR(50),
    payment_method VARCHAR(100),
    transaction_status VARCHAR(100),
    branch VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(100),
    region VARCHAR(100),
    department VARCHAR(100),
    manager VARCHAR(100)
);

CREATE TABLE stage.raw_rfm (
    customer_id TEXT,
    recency TEXT,
    frequency TEXT,
    monetary TEXT,
    r_score TEXT,
    f_score TEXT,
    m_score TEXT,
    rfm_score TEXT,
    segment TEXT,
    value_tier TEXT
);

/*COPY stage.raw_transactions (
    transaction_id, transaction_date, customer_id, product_name, 
    quantity, price, payment_method, transaction_status, 
    region, branch, department, city, country, manager, 
    total_amount, value_tier
)
FROM 'C:/Users/aliak/OneDrive/Desktop/Yakimovich BI Project/Stage 2 - Data Warehouse & ETL/data/initial_load.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ','); */


/* COPY stage.raw_rfm (
    customer_id, recency, frequency, monetary, 
    value_tier, r_score, f_score, m_score, rfm_score, segment
)
FROM 'C:/Users/aliak/OneDrive/Desktop/Yakimovich BI Project/Stage 2 - Data Warehouse & ETL/data/dim_customer_rfm.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ','); */



/*CORE*/

CREATE TABLE core.dim_product (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(150) UNIQUE,
    base_price NUMERIC(12, 2)
);

CREATE TABLE core.dim_branch (
    branch_id SERIAL PRIMARY KEY,
    branch TEXT,
    city TEXT,
    country TEXT,
    region TEXT,
    department TEXT,
    manager TEXT,
    CONSTRAINT uq_branch_location UNIQUE (branch, city, country, region, department, manager)
);

CREATE TABLE core.dim_customer (
    customer_sk SERIAL PRIMARY KEY,     
    customer_id VARCHAR(50) NOT NULL,   
    recency INT,
    frequency INT,
    monetary NUMERIC(15, 4),
    value_tier VARCHAR(50),
    r_score INT,
    f_score INT,
    m_score INT,
    rfm_score INT,
    segment VARCHAR(50),
    region VARCHAR(100),
    branch VARCHAR(100),
    department VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(100),
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,
    is_current BOOLEAN NOT NULL
);

CREATE INDEX idx_dim_customer_current ON core.dim_customer(customer_id) WHERE is_current = TRUE;

CREATE TABLE core.fact_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    transaction_date TIMESTAMP,
    customer_sk INT REFERENCES core.dim_customer(customer_sk),
    product_id INT REFERENCES core.dim_product(product_id),
    branch_id INT REFERENCES core.dim_branch(branch_id),
    quantity NUMERIC(10, 2),
    price NUMERIC(12, 2),
    payment_method VARCHAR(50),
    transaction_status VARCHAR(50),
    region VARCHAR(100),
    branch VARCHAR(100),
    department VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(100)
);


CREATE TEMP TABLE temp_prepared_facts AS
WITH cleaned_raw AS (
    SELECT DISTINCT ON (TRIM(transaction_id))
        TRIM(transaction_id) AS transaction_id,
        CAST(NULLIF(TRIM(transaction_date), '') AS TIMESTAMP) AS transaction_date,
        TRIM(customer_id) AS customer_id,
        TRIM(product_name) AS raw_product_name,
        NULLIF(REGEXP_REPLACE(price, '[^0-9.-]', '', 'g'), '')::NUMERIC(12, 2) AS raw_price,
        NULLIF(REGEXP_REPLACE(quantity, '[^0-9.-]', '', 'g'), '')::NUMERIC(10, 2) AS raw_quantity,
        LOWER(TRIM(payment_method)) AS payment_method,
        LOWER(TRIM(transaction_status)) AS transaction_status,
        TRIM(region) AS region,
        TRIM(branch) AS branch,
        TRIM(department) AS department,
        TRIM(city) AS city,
        TRIM(country) AS country,
        TRIM(manager) AS manager
		FROM stage.raw_transactions
    	WHERE TRIM(transaction_id) <> ''
	      AND TRIM(customer_id) <> ''
	      AND NULLIF(TRIM(transaction_date), '') IS NOT NULL
),
filtered_data AS (
    SELECT 
        transaction_id,
        transaction_date,
        customer_id,
        region, branch, department, city, country, manager,
		CASE 
            WHEN LOWER(TRIM(raw_product_name)) LIKE 'h%' THEN 'Headphones'
            WHEN LOWER(TRIM(raw_product_name)) LIKE 's%' OR LOWER(TRIM(raw_product_name)) LIKE 'phone%' THEN 'Smartphone'
            WHEN LOWER(TRIM(raw_product_name)) LIKE 'c%' THEN 'Coffee Machine'
            WHEN LOWER(TRIM(raw_product_name)) LIKE 't%' THEN 'Tablet'
            WHEN LOWER(TRIM(raw_product_name)) LIKE 'l%' THEN 'Laptop'
            ELSE 'Other'
        END AS product_name,
        CASE WHEN raw_quantity <= 0 THEN NULL ELSE raw_quantity END AS quantity,
        CASE WHEN raw_price <= 0 THEN NULL ELSE raw_price END AS price,
        CASE 
            WHEN transaction_status IN ('completed', 'complete') THEN 'Completed'
            WHEN transaction_status = 'pending' THEN 'Pending'
            WHEN transaction_status = 'failed' THEN 'Failed'
            ELSE 'Not specified'
        END AS transaction_status,
		CASE 
            WHEN LOWER(REPLACE(payment_method, ' ', '')) IN ('creditcard', 'credit_card') THEN 'Credit Card'
            WHEN LOWER(REPLACE(payment_method, ' ', '')) LIKE '%paypal%' THEN 'PayPal'
            WHEN LOWER(REPLACE(payment_method, ' ', '')) LIKE '%cash%' THEN 'Cash'
            ELSE NULL 
        END AS payment_method
    FROM cleaned_raw
),
medians AS (
    SELECT 
        product_name,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) AS product_median_price
    FROM filtered_data
    WHERE price > 0
    GROUP BY product_name
)
SELECT 
    f.transaction_id, 
    f.transaction_date, 
    f.customer_id, 
    f.product_name,
    COALESCE(f.quantity, 1) AS quantity,
    COALESCE(f.price, m.product_median_price, 0) AS price,
    f.payment_method, 
    f.transaction_status,
    f.region, f.branch, f.department, f.city, f.country, f.manager
FROM filtered_data f
LEFT JOIN medians m ON f.product_name = m.product_name;


INSERT INTO core.dim_product (product_name, base_price)
SELECT product_name, ROUND(AVG(price)::NUMERIC, 2) AS base_price
FROM temp_prepared_facts
WHERE product_name IS NOT NULL
GROUP BY product_name
ON CONFLICT (product_name) DO UPDATE 
SET base_price = EXCLUDED.base_price;


INSERT INTO core.dim_branch (branch, city, country, region, department, manager)
SELECT DISTINCT 
    branch, 
    city, 
    country, 
    region, 
    department, 
    manager
FROM temp_prepared_facts
WHERE branch IS NOT NULL
ON CONFLICT (branch, city, country, region, department, manager) DO NOTHING;


UPDATE core.dim_customer old
SET valid_to = CURRENT_TIMESTAMP,
    is_current = FALSE
FROM (
    SELECT DISTINCT ON (TRIM(customer_id))
        TRIM(customer_id) AS customer_id,
        NULLIF(TRIM(value_tier), '') AS value_tier
    FROM stage.raw_rfm
    WHERE customer_id IS NOT NULL
) new_data
WHERE old.customer_id = new_data.customer_id
  AND old.is_current = TRUE
  AND old.value_tier <> new_data.value_tier;


INSERT INTO core.dim_customer (
    customer_id, recency, frequency, monetary, value_tier,
    r_score, f_score, m_score, rfm_score, segment, 
    region, branch, department, city, country,
    valid_from, valid_to, is_current
)
SELECT 
    n.customer_id, n.recency, n.frequency, n.monetary, n.value_tier,
    n.r_score, n.f_score, n.m_score, n.rfm_score, n.segment,
    pf.region, pf.branch, pf.department, pf.city, pf.country,
    CURRENT_TIMESTAMP AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current
FROM (
    SELECT DISTINCT ON (TRIM(customer_id))
        TRIM(customer_id) AS customer_id,
        NULLIF(TRIM(recency), '')::INT AS recency,
        NULLIF(TRIM(frequency), '')::INT AS frequency,
        NULLIF(REGEXP_REPLACE(monetary, '[^0-9.-]', '', 'g'), '')::NUMERIC(15, 4) AS monetary,
        NULLIF(TRIM(value_tier), '') AS value_tier,
        NULLIF(TRIM(r_score), '')::INT AS r_score,
        NULLIF(TRIM(f_score), '')::INT AS f_score,
        NULLIF(TRIM(m_score), '')::INT AS m_score,
        NULLIF(TRIM(rfm_score), '')::INT AS rfm_score,
        NULLIF(TRIM(segment), '') AS segment
    FROM stage.raw_rfm
    WHERE customer_id IS NOT NULL
) n
LEFT JOIN (
    SELECT DISTINCT customer_id, region, branch, department, city, country 
    FROM temp_prepared_facts
) pf ON n.customer_id = pf.customer_id
WHERE NOT EXISTS (
    SELECT 1 FROM core.dim_customer c 
    WHERE c.customer_id = n.customer_id 
      AND c.is_current = TRUE 
      AND c.value_tier = n.value_tier
);


INSERT INTO core.fact_transactions (
    transaction_id, transaction_date, customer_sk, product_id, branch_id,
    quantity, price, payment_method, transaction_status,
    region, branch, department, city, country
)
SELECT 
    pf.transaction_id, 
    pf.transaction_date, 
    dc.customer_sk, 
    p.product_id, 
    b.branch_id,
    pf.quantity, 
    pf.price, 
    pf.payment_method, 
    pf.transaction_status,
    pf.region, pf.branch, pf.department, pf.city, pf.country
FROM temp_prepared_facts pf
JOIN core.dim_product p ON pf.product_name = p.product_name
LEFT JOIN core.dim_customer dc 
    ON pf.customer_id = dc.customer_id 
    AND dc.is_current = TRUE
LEFT JOIN core.dim_branch b 
    ON pf.branch = b.branch 
    AND pf.city = b.city 
    AND pf.country = b.country
    AND pf.region = b.region
    AND pf.department = b.department
    AND pf.manager = b.manager
ON CONFLICT (transaction_id) DO NOTHING;



/*MART*/

CREATE TABLE mart.dim_product AS
SELECT product_id, product_name, base_price
FROM core.dim_product;

ALTER TABLE mart.dim_product ADD PRIMARY KEY (product_id);


CREATE TABLE mart.dim_branch AS
SELECT 
    branch_id,
    branch,
    city,
    country,
    region,
    department,
    manager
FROM core.dim_branch;

ALTER TABLE mart.dim_branch ADD PRIMARY KEY (branch_id);


CREATE TABLE mart.branch AS
SELECT DISTINCT
    branch_id,
    branch,
    city,
    country,
    region,
    department,
    manager
FROM mart.dim_branch;

ALTER TABLE mart.branch ADD PRIMARY KEY (branch_id);


CREATE TABLE mart.dim_customer AS
SELECT 
    customer_sk, 
    customer_id, 
    segment, 
    value_tier, 
    recency, 
    frequency, 
    monetary, 
    r_score, 
    f_score, 
    m_score, 
    rfm_score, 
    region, 
    branch, 
    department, 
    city, 
    country,
    valid_from, 
    valid_to, 
    is_current
FROM core.dim_customer;

ALTER TABLE mart.dim_customer ADD PRIMARY KEY (customer_sk);


CREATE TABLE mart.dim_date (
    date_id INT PRIMARY KEY,
    date DATE UNIQUE,
    year INT,
    quarter INT,
    month INT,
    month_name VARCHAR(20),
    day_of_week VARCHAR(20),
    is_weekend BOOLEAN
);

INSERT INTO mart.dim_date (date_id, date, year, quarter, month, month_name, day_of_week, is_weekend)
SELECT DISTINCT 
    TO_CHAR(transaction_date, 'YYYYMMDD')::INT AS date_id,
    transaction_date::DATE AS date,
    EXTRACT(YEAR FROM transaction_date)::INT AS year,
    EXTRACT(QUARTER FROM transaction_date)::INT AS quarter,
    EXTRACT(MONTH FROM transaction_date)::INT AS month,
    TRIM(TO_CHAR(transaction_date, 'Month')) AS month_name,
    TRIM(TO_CHAR(transaction_date, 'Day')) AS day_of_week,
    CASE WHEN EXTRACT(ISODOW FROM transaction_date) IN (6, 7) THEN TRUE ELSE FALSE END AS is_weekend
FROM core.fact_transactions
WHERE transaction_date IS NOT NULL
ON CONFLICT (date_id) DO NOTHING;


CREATE TABLE mart.fact_sales (
    transaction_id VARCHAR(50) PRIMARY KEY,
    transaction_date TIMESTAMP NOT NULL,
    customer_id VARCHAR(50),
    customer_sk INT, 
    product_id INT,
    branch_id INT,
    quantity NUMERIC(10, 2),
    price NUMERIC(12, 2),
    total_amount NUMERIC(14, 2),
    payment_method VARCHAR(50),
    transaction_status VARCHAR(50),
    region VARCHAR(100),
    branch VARCHAR(100),
    department VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(100)
);


INSERT INTO mart.fact_sales (
    transaction_id, transaction_date, customer_id, customer_sk, product_id, branch_id,
    quantity, price, total_amount, payment_method, transaction_status,
    region, branch, department, city, country
)
SELECT 
    f.transaction_id, f.transaction_date, dc.customer_id, f.customer_sk, f.product_id, f.branch_id,
    f.quantity, f.price,
    ROUND(f.quantity * f.price, 2) AS total_amount,
    f.payment_method, f.transaction_status,
    f.region, f.branch, f.department, f.city, f.country
FROM core.fact_transactions f
JOIN core.dim_product p ON f.product_id = p.product_id
JOIN core.dim_customer dc ON f.customer_sk = dc.customer_sk
WHERE f.transaction_status = 'Completed';



/* A fintech platform tracks merchant transactions alongside the customer's risk or value tier. 
A high-net-worth client makes large investments in Q1 while in the Standard tier, but gets upgraded to VIP in Q2. 
If we use SCD Type 1 and overwrite their profile, historical Q1 reports will retroactively reclassify those past transactions under the VIP tier. 
This distorts compliance audits and historical performance tracking. 
SCD Type 2 avoids this by preserving historical versions, ensuring Q1 transactions remain strictly linked to the Standard tier context active at that time. */


/* A natural key must remain unique, preventing the database from accepting a second active profile row for the same client ID when their attributes change. 
A surrogate key solves this by giving every single version of a customer profile a unique ID. 
This allows the same Client ID to appear multiple times across history, and lets the transaction table point to the exact version of the customer that was active when the record was created. */