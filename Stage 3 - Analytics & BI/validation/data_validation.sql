SELECT 
    COALESCE(
        SUM(quantity * price), 
        0
    ) AS total_revenue
FROM mart.fact_sales
WHERE transaction_status = 'Completed';




SELECT 
    COUNT(DISTINCT f.customer_id) AS customers_at_risk
FROM mart.fact_sales f
JOIN mart.dim_customer d ON f.customer_id = d.customer_id
WHERE d.segment = 'At Risk';




SELECT 
    COALESCE(
        SUM(CASE WHEN transaction_status = 'Completed' 
        	THEN quantity * price END) / 
        NULLIF(COUNT(DISTINCT CASE WHEN transaction_status = 'Completed' 
        	THEN transaction_id END), 0),
        0
    ) AS avg_order_value
FROM mart.fact_sales;















