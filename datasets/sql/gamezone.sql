SELECT *
FROM orders;

SELECT SUM(order_amount) AS gmv
FROM orders;

CREATE COLUMN (
SELECT
    SUM(REPLACE(usd_price, ',', '.')::numeric) AS GMV
FROM orders);

CREATE OR REPLACE VIEW v_orders_clean AS
SELECT
    order_id,
    user_id,
    purchase_ts,
    purchase_year,
    purchase_month,
    marketing_channel_cleaned,
    purchase_platform,
    product_name_cleaned,
    country_code,
    region,
    time_to_ship,
    refund_ts,
    REPLACE(usd_price, ',', '.')::numeric AS usd_price
FROM orders;


CREATE OR REPLACE VIEW v_ecommerce_kpis AS
SELECT
    SUM(usd_price) AS gmv,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    SUM(usd_price) / COUNT(DISTINCT order_id) AS aov,
    ROUND(
        COUNT(CASE WHEN refund_ts IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS refund_rate_pct
FROM v_orders_clean;

CREATE OR REPLACE VIEW v_monthly_performance AS
SELECT
    purchase_year,
    purchase_month,
    ROUND(SUM(usd_price), 2) AS gmv,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    ROUND(SUM(usd_price) / COUNT(DISTINCT order_id), 2) AS aov
FROM v_orders_clean
GROUP BY purchase_year, purchase_month
ORDER BY purchase_year, purchase_month;

CREATE OR REPLACE VIEW v_monthly_gmv_growth AS
WITH monthly_gmv AS (
    SELECT
        purchase_year,
        purchase_month,
        SUM(usd_price) AS gmv
    FROM v_orders_clean
    GROUP BY purchase_year, purchase_month
)
SELECT
    purchase_year,
    purchase_month,
    ROUND(gmv, 2) AS gmv,
    ROUND(LAG(gmv) OVER (ORDER BY purchase_year, purchase_month), 2) AS previous_gmv,
    ROUND(
        (gmv - LAG(gmv) OVER (ORDER BY purchase_year, purchase_month)) * 100.0
        / NULLIF(LAG(gmv) OVER (ORDER BY purchase_year, purchase_month), 0),
        2
    ) AS gmv_growth_pct
FROM monthly_gmv
ORDER BY purchase_year, purchase_month;

CREATE OR REPLACE VIEW v_marketing_performance AS
SELECT
    marketing_channel_cleaned,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    ROUND(SUM(usd_price), 2) AS gmv,
    ROUND(SUM(usd_price) / COUNT(DISTINCT order_id), 2) AS aov,
    ROUND(SUM(usd_price) / COUNT(DISTINCT user_id), 2) AS revenue_per_customer,
    ROUND(
        COUNT(CASE WHEN refund_ts IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS refund_rate_pct
FROM v_orders_clean
WHERE marketing_channel_cleaned IS NOT NULL
GROUP BY marketing_channel_cleaned
ORDER BY gmv DESC;

CREATE OR REPLACE VIEW v_platform_performance AS
SELECT
    purchase_platform,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    ROUND(SUM(usd_price), 2) AS gmv,
    ROUND(SUM(usd_price) / COUNT(DISTINCT order_id), 2) AS aov
FROM v_orders_clean
WHERE purchase_platform IS NOT NULL
GROUP BY purchase_platform
ORDER BY gmv DESC;

CREATE OR REPLACE VIEW v_region_performance AS
SELECT
    region,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT user_id) AS total_customers,
    ROUND(SUM(usd_price), 2) AS gmv,
    ROUND(SUM(usd_price) / COUNT(DISTINCT order_id), 2) AS aov
FROM v_orders_clean
WHERE region IS NOT NULL
GROUP BY region
ORDER BY gmv DESC;

CREATE OR REPLACE VIEW v_top_products_by_revenue AS
SELECT
    product_name_cleaned,
    COUNT(*) AS purchase_count,
    SUM(usd_price) AS gmv,
    SUM(usd_price) / COUNT(DISTINCT order_id) AS aov,
    ROUND(
        COUNT(CASE WHEN refund_ts IS NOT NULL THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS refund_rate_pct
FROM v_orders_clean
WHERE product_name_cleaned IS NOT NULL
GROUP BY product_name_cleaned
ORDER BY gmv DESC;

CREATE OR REPLACE VIEW v_customer_ltv AS
SELECT
    user_id,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(usd_price), 2) AS lifetime_value,
    MIN(purchase_ts) AS first_purchase_ts,
    MAX(purchase_ts) AS last_purchase_ts
FROM v_orders_clean
GROUP BY user_id
ORDER BY lifetime_value DESC;

CREATE OR REPLACE VIEW v_customer_segments AS
WITH customer_orders AS (
    SELECT
        user_id,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(usd_price) AS lifetime_value
    FROM v_orders_clean
    GROUP BY user_id
)
SELECT
    user_id,
    total_orders,
    ROUND(lifetime_value, 2) AS lifetime_value,
    CASE
        WHEN total_orders = 1 THEN '1 order'
        WHEN total_orders BETWEEN 2 AND 3 THEN '2-3 orders'
        WHEN total_orders BETWEEN 4 AND 5 THEN '4-5 orders'
        ELSE '6+ orders'
    END AS customer_segment
FROM customer_orders;

CREATE OR REPLACE VIEW v_repeat_purchase_rate AS
WITH customer_orders AS (
  SELECT
    user_id,
    COUNT(DISTINCT order_id) AS total_orders
  FROM v_orders_clean
  GROUP BY user_id
)
SELECT
  ROUND(
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
    2
  ) AS repeat_purchase_rate_pct,
  SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customer_count
FROM customer_orders;



