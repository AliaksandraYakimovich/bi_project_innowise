SELECT 
    ROUND(SUM(total_amount) / 1000000000.0, 2) AS total_revenue
FROM 
    mart.fact_sales;

SELECT 
    COUNT(DISTINCT customer_id) AS at_risk_count
FROM 
    mart.dim_customer
WHERE 
    segment = 'At Risk' 
    AND is_current = TRUE;


SELECT 
    ROUND(SUM(total_amount) / (1000 * COUNT(DISTINCT transaction_id)), 2) AS average_order_value
FROM 
    mart.fact_sales;

