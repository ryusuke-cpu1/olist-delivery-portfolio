WITH segments AS (
    SELECT
        'route_scope' AS segment_type,
        CASE WHEN same_state THEN 'Same state' ELSE 'Interstate' END AS segment,
        is_late,
        delivery_days,
        review_score
    FROM order_delivery_mart
    WHERE same_state IS NOT NULL

    UNION ALL

    SELECT 'distance_band', distance_band, is_late, delivery_days, review_score
    FROM order_delivery_mart
    WHERE distance_band <> 'Unknown'

    UNION ALL

    SELECT 'weight_band', weight_band, is_late, delivery_days, review_score
    FROM order_delivery_mart
    WHERE weight_band <> 'Unknown'

    UNION ALL

    SELECT
        'item_count',
        CASE
            WHEN item_count = 1 THEN '1 item'
            WHEN item_count = 2 THEN '2 items'
            ELSE '3+ items'
        END,
        is_late,
        delivery_days,
        review_score
    FROM order_delivery_mart
)
SELECT
    segment_type,
    segment,
    COUNT(*) AS orders,
    ROUND(100 * AVG(is_late::INTEGER), 2) AS late_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM segments
GROUP BY 1, 2
ORDER BY 1, 5 DESC;

