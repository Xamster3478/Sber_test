WITH PriceDifferences AS (
    SELECT
        product_name,
        price_date,
        price,
        LAG(price) OVER (PARTITION BY product_name ORDER BY price_date) AS prev_price
    FROM product_prices
),
StableDays AS (
    SELECT
        product_name,
        price_date,
        price,
        prev_price,
        CASE
            WHEN prev_price IS NULL OR ABS(price - prev_price) / prev_price > 0.03 THEN 0
            ELSE 1
        END AS is_stable
    FROM PriceDifferences
),
StablePeriods AS (
    SELECT
        product_name,
        price_date,
        price,
        is_stable,
        SUM(CASE WHEN is_stable = 0 THEN 1 ELSE 0 END) OVER (PARTITION BY product_name ORDER BY price_date) AS period_id
    FROM StableDays
),
StableCounts AS (
    SELECT
        product_name,
        COUNT(*) AS days_num
    FROM StablePeriods
    WHERE is_stable = 1
    GROUP BY product_name, period_id
    HAVING COUNT(*) > 1
),
MaxStable AS (
    SELECT
        product_name,
        MAX(days_num) AS max_days_num
    FROM StableCounts
    GROUP BY product_name
)
SELECT
    p.product_name,
    COALESCE(m.max_days_num, -1) AS days_num
FROM
    (SELECT DISTINCT product_name FROM product_prices) p
LEFT JOIN MaxStable m ON p.product_name = m.product_name;
