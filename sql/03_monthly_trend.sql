SELECT
    purchase_month,
    COUNT(*) AS orders,
    ROUND(100 * AVG(is_late::INTEGER), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(MEDIAN(delivery_days), 2) AS median_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_delivery_mart
GROUP BY 1
HAVING COUNT(*) >= 100
ORDER BY 1;

