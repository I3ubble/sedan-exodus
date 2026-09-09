-- sedan-exodus: exploratory queries
-- Run with: sqlite3 sedan_data.db < queries.sql
-- or open sqlite3 sedan_data.db and paste sections interactively

-- ============================================
-- SECTION 1: Sanity checks (orientation, not analysis)
-- ============================================

-- 1a. Row and model counts -- does this match the Python import output?
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT model) AS model_count
FROM sedan_sales;

-- 1b. Year range per model -- catches launch dates, discontinuations, gaps
SELECT brand, model, MIN(year) AS first_year, MAX(year) AS last_year, COUNT(*) AS n_rows
FROM sedan_sales
GROUP BY brand, model
ORDER BY brand, model;

-- 1c. How much US data is missing (NULL) per model?
-- A model with launch-year NULLs (Genesis) is expected.
-- A model with mid-series NULLs (Mercedes E-Class) is the data gap we flagged.
SELECT brand, model,
       COUNT(*) AS total_rows,
       SUM(CASE WHEN units_sold_us IS NULL THEN 1 ELSE 0 END) AS null_us_rows
FROM sedan_sales
GROUP BY brand, model
HAVING null_us_rows > 0
ORDER BY null_us_rows DESC;

-- 1d. Sanity check on tier labels -- should be exactly 'luxury' and 'mainstream'
SELECT tier, COUNT(DISTINCT model) AS models, COUNT(*) AS rows
FROM sedan_sales
GROUP BY tier;

-- 1e. Spot-check one full series to eyeball against the source
-- (swap the model name to check others)
SELECT year, units_sold_us, yoy_us_pct, units_sold_canada, yoy_canada_pct
FROM sedan_sales
WHERE model = 'IS'
ORDER BY year;

-- ============================================
-- SECTION 2: Basic orientation (still not the hypothesis)
-- ============================================

-- 2a. Peak US sales year for each model
SELECT brand, model, year AS peak_year, units_sold_us AS peak_units
FROM sedan_sales s1
WHERE units_sold_us = (
    SELECT MAX(units_sold_us)
    FROM sedan_sales s2
    WHERE s2.model = s1.model AND s2.brand = s1.brand
)
ORDER BY brand, model;

-- 2b. Most recent year's US units per model, side by side with peak
-- (a rough first look at "how far off peak is each model")
SELECT brand, model,
       MAX(CASE WHEN year = (SELECT MAX(year) FROM sedan_sales s2 WHERE s2.model = s1.model) THEN units_sold_us END) AS latest_units,
       MAX(units_sold_us) AS peak_units
FROM sedan_sales s1
GROUP BY brand, model
ORDER BY brand, model;

-- 2c. Total rows by tier and body_style -- just confirming shape of the dataset
SELECT tier, body_style, COUNT(*) AS rows
FROM sedan_sales
GROUP BY tier, body_style;

-- ============================================
-- SECTION 3: Peak-to-latest sales decline per model
-- ============================================

WITH peak_sales AS (
    -- PURPOSE: get each model's single best US sales year.
    -- GROUP BY collapses all rows per model into one row; MAX() picks
    -- the highest units_sold_us within that group.
    SELECT
        brand,
        model,
        tier,
        MAX(units_sold_us) AS peak_units
    FROM sedan_sales
    GROUP BY brand, model, tier
),

latest_sales AS (
    -- PURPOSE: get each model's units_sold_us in its OWN most recent
    -- year WITH REAL SALES DATA (not just its most recent row).
    --
    -- s2.units_sold_us > 0 is the key fix here: without it, this
    -- subquery would treat a discontinued model's placeholder zero
    -- row (e.g. Passat's 2025: 0, added to confirm discontinuation)
    -- as if it were a real "latest" data point, producing a fake
    -- ~-100% decline. Requiring > 0 makes it skip past placeholder
    -- years and find the last year the model actually sold units.
    --
    -- The outer WHERE doesn't need this same condition repeated --
    -- once the inner subquery returns the correct year, matching
    -- s1.year against it already pulls the one row for that model
    -- at that year, which is guaranteed to be the real-sales row.
    SELECT
        s1.brand,
        s1.model,
        s1.tier,
        s1.units_sold_us AS latest_units,
        s1.year AS latest_year
    FROM sedan_sales s1
    WHERE s1.year = (
        SELECT MAX(s2.year)
        FROM sedan_sales s2
        WHERE s2.model = s1.model AND s2.brand = s1.brand AND s2.units_sold_us > 0
    )
)

-- PURPOSE: join peak and latest together per model, then compute the
-- decline %. Negative = decline (expected for nearly every model here).
SELECT
    p.tier,
    p.brand,
    p.model,
    p.peak_units,
    l.latest_year,
    l.latest_units,
    ROUND(
        (CAST(l.latest_units AS REAL) - p.peak_units) / p.peak_units * 100,
        1
    ) AS pct_change_peak_to_latest
FROM peak_sales p
JOIN latest_sales l
    ON p.brand = l.brand AND p.model = l.model
ORDER BY pct_change_peak_to_latest ASC;


-- PURPOSE: Join the decline % together and Group by tier to find the AVG sale decline rate on both tiers
WITH peak_sales AS (
    SELECT brand, model, tier, MAX(units_sold_us) AS peak_units
    FROM sedan_sales
    GROUP BY brand, model, tier
),

latest_sales AS (
    SELECT
        s1.brand, s1.model, s1.tier,
        s1.units_sold_us AS latest_units,
        s1.year AS latest_year
    FROM sedan_sales s1
    WHERE s1.year = (
        SELECT MAX(s2.year)
        FROM sedan_sales s2
        WHERE s2.model = s1.model AND s2.brand = s1.brand AND s2.units_sold_us > 0
    )
),

decline_by_model AS (
    SELECT
        p.tier, p.brand, p.model,
        ROUND((CAST(l.latest_units AS REAL) - p.peak_units) / p.peak_units * 100, 1) AS pct_change_peak_to_latest
    FROM peak_sales p
    JOIN latest_sales l ON p.brand = l.brand AND p.model = l.model
)

-- PURPOSE: Stress-test the tier comparison above by excluding the two
-- near-total decline cases driven by discontinuation (VW Passat -98.1%,
-- Audi A4 -99.0%) rather than gradual demand decline. One of these sits
-- in each tier, so this checks whether the luxury-vs-mainstream gap is
-- a real pattern or partly an artifact of these two extreme cases.
--
-- RESULT: excluding both outliers WIDENED the gap rather than narrowing
-- it (8.5 pts -> 14.1 pts). Mainstream's average improved more
-- (-58.6 -> -50.7) than luxury's did (-67.1 -> -64.8) once its own
-- outlier (Passat) was removed. This strengthens the hypothesis rather
-- than undermining it -- the luxury tier's steeper decline isn't an
-- artifact of one bad discontinued nameplate skewing the average.
SELECT tier, AVG(pct_change_peak_to_latest) AS avg_decline_pct, COUNT(*) AS n_models
FROM decline_by_model
WHERE model NOT IN ('Passat', 'A4')
GROUP BY tier;
SELECT tier, AVG(pct_change_peak_to_latest) AS avg_decline_pct, COUNT(*) AS n_models
FROM decline_by_model
GROUP BY tier;

-- PURPOSE: Discontinued Flag (1 is discontinued 0 otherwise)

WITH peak_sales AS (
    SELECT brand, model, tier, MAX(units_sold_us) AS peak_units
    FROM sedan_sales
    GROUP BY brand, model, tier
),

latest_sales AS (
    SELECT
        s1.brand, s1.model, s1.tier,
        s1.units_sold_us AS latest_units,
        s1.year AS latest_year
    FROM sedan_sales s1
    WHERE s1.year = (
        SELECT MAX(s2.year)
        FROM sedan_sales s2
        WHERE s2.model = s1.model AND s2.brand = s1.brand AND s2.units_sold_us > 0
    )
),

decline_by_model AS (
    SELECT
        p.tier, p.brand, p.model,
        ROUND((CAST(l.latest_units AS REAL) - p.peak_units) / p.peak_units * 100, 1) AS pct_change_peak_to_latest
    FROM peak_sales p
    JOIN latest_sales l ON p.brand = l.brand AND p.model = l.model
)


SELECT tier, brand, model, pct_change_peak_to_latest,
       CASE WHEN model IN ('Passat', 'A4', 'A8', 'LS') THEN 1 ELSE 0 END AS discontinued
FROM decline_by_model
ORDER BY discontinued DESC;

--show each model's decline severity ranked against only its own tier's peers

WITH peak_sales AS (
    SELECT brand, model, tier, MAX(units_sold_us) AS peak_units
    FROM sedan_sales
    GROUP BY brand, model, tier
),

latest_sales AS (
    SELECT
        s1.brand, s1.model, s1.tier,
        s1.units_sold_us AS latest_units,
        s1.year AS latest_year
    FROM sedan_sales s1
    WHERE s1.year = (
        SELECT MAX(s2.year)
        FROM sedan_sales s2
        WHERE s2.model = s1.model AND s2.brand = s1.brand AND s2.units_sold_us > 0
    )
),

decline_by_model AS (
    SELECT
        p.tier, p.brand, p.model,
        ROUND((CAST(l.latest_units AS REAL) - p.peak_units) / p.peak_units * 100, 1) AS pct_change_peak_to_latest
    FROM peak_sales p
    JOIN latest_sales l ON p.brand = l.brand AND p.model = l.model
)

SELECT tier, brand, model, pct_change_peak_to_latest,
       RANK() OVER (PARTITION BY tier ORDER BY pct_change_peak_to_latest ASC) AS tier_rank
FROM decline_by_model;

--

SELECT model, year, units_sold_us, prev_year_units,
       ROUND((CAST(units_sold_us AS REAL) - prev_year_units) / prev_year_units * 100) AS yoy_pct_change
FROM (
    SELECT model, year, units_sold_us,
           LAG(units_sold_us) OVER (PARTITION BY model ORDER BY year) AS prev_year_units
    FROM sedan_sales
    WHERE model IN ('LS', 'A4', 'A8', 'Passat') AND year >= 2015
)
ORDER BY model, year;