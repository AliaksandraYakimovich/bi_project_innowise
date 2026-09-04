CREATE SCHEMA stage;
CREATE SCHEMA core;
CREATE SCHEMA mart;



/*STAGE*/

CREATE TABLE stage.raw_transactions (
    transaction_id TEXT,
    transaction_date TEXT,
    customer_id TEXT,
    product_name TEXT,
    quantity TEXT,
    price TEXT,
    payment_method TEXT,
    transaction_status TEXT
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
    segment TEXT
);



/*CORE*/

CREATE TABLE core.fact_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY,
    transaction_date TIMESTAMP,
    customer_id VARCHAR(50),
    product_name VARCHAR(150),
    quantity NUMERIC(10, 2),
    price NUMERIC(12, 2),
    payment_method VARCHAR(50),
    transaction_status VARCHAR(50)
);


TRUNCATE TABLE core.fact_transactions CASCADE;

WITH cleaned_raw AS (
    SELECT DISTINCT ON (TRIM(transaction_id))
        TRIM(transaction_id) AS transaction_id,
        CAST(NULLIF(TRIM(transaction_date), '') AS TIMESTAMP) AS transaction_date,
        TRIM(customer_id) AS customer_id,
        TRIM(product_name) AS raw_product_name,
        NULLIF(REGEXP_REPLACE(price, '[^0-9.-]', '', 'g'), '')::NUMERIC(12, 2) AS raw_price,
        NULLIF(REGEXP_REPLACE(quantity, '[^0-9.-]', '', 'g'), '')::NUMERIC(10, 2) AS raw_quantity,
        LOWER(TRIM(payment_method)) AS payment_method,
        LOWER(TRIM(transaction_status)) AS transaction_status
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
INSERT INTO core.fact_transactions (
    transaction_id, transaction_date, customer_id, product_name, 
    quantity, price, payment_method, transaction_status
)
SELECT 
    f.transaction_id, f.transaction_date, f.customer_id, f.product_name,
    COALESCE(f.quantity, 1) AS quantity,
    COALESCE(f.price, m.product_median_price, 0) AS price,
    f.payment_method, f.transaction_status
FROM filtered_data f
LEFT JOIN medians m ON f.product_name = m.product_name;

CREATE TABLE core.dim_product (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(150) UNIQUE,
    base_price NUMERIC(12, 2)
);

INSERT INTO core.dim_product (product_name, base_price)
SELECT product_name, ROUND(AVG(price), 2) AS base_price
FROM core.fact_transactions
WHERE product_name IS NOT NULL
GROUP BY product_name
ON CONFLICT (product_name) DO UPDATE 
SET base_price = EXCLUDED.base_price;


CREATE TABLE core.dim_customer_rfm (
    customer_sk SERIAL PRIMARY KEY,     
    customer_id VARCHAR(50) NOT NULL,   
    recency INT,
    frequency INT,
    monetary NUMERIC(15, 4),
    r_score INT,
    f_score INT,
    m_score INT,
    rfm_score INT,
    segment VARCHAR(50),
    valid_from TIMESTAMP NOT NULL,
    valid_to TIMESTAMP,
    is_current BOOLEAN NOT NULL
);

CREATE INDEX idx_dim_customer_current ON core.dim_customer_rfm(customer_id) WHERE is_current = TRUE;

INSERT INTO core.dim_customer_rfm (
    customer_id, recency, frequency, monetary, 
    r_score, f_score, m_score, rfm_score, segment, 
    valid_from, valid_to, is_current
)
SELECT DISTINCT ON (TRIM(customer_id))
    TRIM(customer_id) AS customer_id,
    NULLIF(TRIM(recency), '')::INT,
    NULLIF(TRIM(frequency), '')::INT,
    NULLIF(REGEXP_REPLACE(monetary, '[^0-9.-]', '', 'g'), '')::NUMERIC(15, 4),
    NULLIF(TRIM(r_score), '')::INT,
    NULLIF(TRIM(f_score), '')::INT,
    NULLIF(TRIM(m_score), '')::INT,
    NULLIF(TRIM(rfm_score), '')::INT,
    NULLIF(TRIM(segment), '') AS segment,
    CURRENT_TIMESTAMP AS valid_from,
    NULL AS valid_to,
    TRUE AS is_current
FROM stage.raw_rfm
WHERE customer_id IS NOT NULL;



/*MART*/

CREATE TABLE mart.dim_product AS
SELECT product_id, product_name, base_price
FROM core.dim_product;

ALTER TABLE mart.dim_product ADD PRIMARY KEY (product_id);


CREATE TABLE mart.dim_customer AS
SELECT 
    customer_sk, customer_id, segment, recency, frequency, 
    monetary, r_score, f_score, m_score, rfm_score, 
    valid_from, valid_to, is_current
FROM core.dim_customer_rfm;

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
    product_name VARCHAR(150),
    quantity NUMERIC(10, 2),
    price NUMERIC(12, 2),
    total_amount NUMERIC(14, 2),
    payment_method VARCHAR(50),
    transaction_status VARCHAR(50)
);


INSERT INTO mart.fact_sales (
    transaction_id, transaction_date, customer_id, customer_sk, product_id, 
    product_name, quantity, price, total_amount, payment_method, transaction_status
)
SELECT 
    f.transaction_id, f.transaction_date, f.customer_id, dc.customer_sk, p.product_id,
    f.product_name, f.quantity, f.price,
    ROUND(f.quantity * f.price, 2) AS total_amount,
    f.payment_method, f.transaction_status
FROM core.fact_transactions f
LEFT JOIN core.dim_product p ON f.product_name = p.product_name
LEFT JOIN core.dim_customer_rfm dc 
    ON f.customer_id = dc.customer_id 
    AND f.transaction_date >= dc.valid_from 
    AND (f.transaction_date < dc.valid_to OR dc.valid_to IS NULL);

/*A university bookstore tracks student purchases along with their current dorm building (like Dorm A or Dorm B). 
A student named buys a book in September while living in Dorm A, and later moves to Dorm B.
If we use SCD Type 1 and just overwrite the old dorm address, September's sales report will wrongly show that student lived in Dorm B from the start. 
This ruins historical delivery stats and department budgets for past months. 
SCD Type 2 avoids this by saving the history, so September's purchases stay correctly linked to Dorm A*/


/*A natural key must be unique in a table, so you cannot simply insert a second row for the same student when their details change—the database will block it as a duplicate. 
A surrogate key solves this by giving every single version of a student profile a unique ID. 
This allows the same Student ID to appear multiple times across history, and lets the sales/transaction table point to the exact version of the student that was active when the record was created*/


