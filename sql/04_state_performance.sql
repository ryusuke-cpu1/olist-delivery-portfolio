SELECT
    customer_state,
    COUNT(*) AS orders,
    ROUND(100 * AVG(is_late::INTEGER), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(MEDIAN(delivery_days), 2) AS median_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(distance_km), 0) AS avg_distance_km
FROM order_delivery_mart
GROUP BY 1
HAVING COUNT(*) >= 500
ORDER BY late_rate_pct DESC, orders DESC;

