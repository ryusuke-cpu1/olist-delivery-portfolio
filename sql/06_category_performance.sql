SELECT
    category_name,
    COUNT(*) AS orders,
    ROUND(SUM(item_value), 2) AS item_value_brl,
    ROUND(100 * AVG(is_late::INTEGER), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(AVG(total_weight_g) / 1000, 2) AS avg_weight_kg
FROM order_delivery_mart
GROUP BY 1
HAVING COUNT(*) >= 500
ORDER BY late_rate_pct DESC, orders DESC;

