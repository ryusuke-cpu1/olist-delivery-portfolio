SELECT
    delay_bucket,
    COUNT(*) AS orders,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS order_share_pct,
    ROUND(AVG(delay_days), 2) AS avg_delay_days,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    ROUND(100 * AVG((review_score <= 2)::INTEGER), 2) AS low_review_rate_pct,
    ROUND(100 * AVG((review_score = 5)::INTEGER), 2) AS five_star_rate_pct
FROM order_delivery_mart
WHERE review_score IS NOT NULL
GROUP BY 1
ORDER BY CASE delay_bucket
    WHEN '7+ days early' THEN 1
    WHEN '1-6 days early' THEN 2
    WHEN '<1 day late' THEN 3
    WHEN '1-3 days late' THEN 4
    WHEN '4-7 days late' THEN 5
    ELSE 6
END;

