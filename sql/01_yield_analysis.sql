WITH district_quarter AS (
    SELECT
        area_name_en,
        YEAR(instance_date_parsed) AS txn_year,
        QUARTER(instance_date_parsed) AS txn_quarter,
        COUNT(*) AS txn_count,
        ROUND(AVG(meter_sale_price), 2) AS avg_price_per_sqm
    FROM transactions_raw
    WHERE trans_group_en = 'Sales'
      AND property_usage_en = 'Residential'
    GROUP BY area_name_en, YEAR(instance_date_parsed), QUARTER(instance_date_parsed)
),

growth_calc AS (
    SELECT
        area_name_en,
        txn_year,
        txn_quarter,
        txn_count,
        avg_price_per_sqm,
        ROUND(
            (avg_price_per_sqm - LAG(avg_price_per_sqm) OVER (
                PARTITION BY area_name_en ORDER BY txn_year, txn_quarter
            )) / LAG(avg_price_per_sqm) OVER (
                PARTITION BY area_name_en ORDER BY txn_year, txn_quarter
            ) * 100
        , 2) AS qoq_price_growth_pct,
        RANK() OVER (
            PARTITION BY txn_year, txn_quarter ORDER BY txn_count DESC
        ) AS velocity_rank_that_quarter
    FROM district_quarter
),

yield_calc AS (
    SELECT
        g.area_name_en,
        g.txn_year,
        g.txn_quarter,
        g.txn_count,
        g.avg_price_per_sqm,
        g.qoq_price_growth_pct,
        g.velocity_rank_that_quarter,
        ROUND(r.avg_annual_rent_per_sqft * 10.7639, 2) AS avg_annual_rent_per_sqm,
        ROUND(s.avg_service_charge_per_sqft * 10.7639, 2) AS avg_service_charge_per_sqm,
        ROUND(
            (r.avg_annual_rent_per_sqft * 10.7639) / g.avg_price_per_sqm * 100
        , 2) AS gross_yield_pct,
        ROUND(
            ((r.avg_annual_rent_per_sqft * 10.7639) - (s.avg_service_charge_per_sqft * 10.7639))
            / g.avg_price_per_sqm * 100
        , 2) AS net_yield_pct
    FROM growth_calc g
    LEFT JOIN rental_benchmark r ON g.area_name_en = r.area_name_en
    LEFT JOIN service_charge_benchmark s ON g.area_name_en = s.area_name_en
)

SELECT
    *,
    -- Composite liquidity score: lower velocity_rank is better (more liquid), so we invert it.
    -- Weighted 60% liquidity (velocity), 40% yield strength - documented assumption, adjust as needed.
    ROUND(
        (0.6 * (8 - velocity_rank_that_quarter)) + (0.4 * net_yield_pct)
    , 2) AS liquidity_score
FROM yield_calc
ORDER BY area_name_en, txn_year, txn_quarter;