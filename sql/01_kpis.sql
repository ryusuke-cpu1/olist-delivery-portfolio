SELECT
    COUNT(*) AS delivered_orders,
    MIN(order_purchase_timestamp)::DATE AS first_purchase_date,
    MAX(order_purchase_timestamp)::DATE AS last_purchase_date,
    ROUND(100 * AVG(is_late::INTEGER), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(MEDIAN(delivery_days), 2) AS median_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100 * AVG((review_score <= 2)::INTEGER), 2) AS low_review_rate_pct,
    ROUND(SUM(item_value), 2) AS item_value_brl,
    ROUND(SUM(freight_value), 2) AS freight_value_brl,
    ROUND(100 * SUM(freight_value) / NULLIF(SUM(item_value), 0), 2) AS freight_to_item_value_pct
FROM order_delivery_mart;

