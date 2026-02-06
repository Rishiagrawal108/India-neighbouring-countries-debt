--- International Debt Statistics - PPG Bilateral Debt ---

-- How much India lent each year

SELECT 
    d.year,
    SUM(d.amount) AS total_amount_lent_by_india
FROM bilateral_debt_table d
JOIN creditor_country_table c
    ON d.creditor_id = c.creditor_id
WHERE c.creditor_country_name = 'India'
GROUP BY d.year
ORDER BY d.year;

-- Which country borrowed the most

SELECT 
    db.debtor_country_name AS country,
    SUM(d.amount) AS total_borrowed
FROM bilateral_debt_table d
JOIN debtor_country_table db 
    ON d.debtor_id = db.debtor_id
GROUP BY db.debtor_country_name
ORDER BY total_borrowed DESC;

-- Compare 2000 vs 2001

SELECT 
    SUM(CASE WHEN year = 2000 THEN amount END) AS debt_2000,
    SUM(CASE WHEN year = 2001 THEN amount END) AS debt_2001,
    SUM(CASE WHEN year = 2001 THEN amount END) 
      - SUM(CASE WHEN year = 2000 THEN amount END) AS difference
FROM bilateral_debt_table
WHERE year IN (2000, 2001);

-- Total statistics

SELECT 
    COUNT(*) AS total_records,
    COUNT(DISTINCT year) AS total_years,
    COUNT(DISTINCT debtor_id) AS total_borrower_countries,
    COUNT(DISTINCT creditor_id) AS total_creditor_countries,
    SUM(amount) AS total_debt_amount
FROM bilateral_debt_table;

-- Running total of debt per borrower country

SELECT
    b.year,
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt,
    SUM(SUM(b.amount)) OVER (PARTITION BY b.debtor_id ORDER BY b.year) AS cumulative_debt
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.year,
    b.debtor_id,
    d.debtor_country_name
ORDER BY
    d.debtor_country_name,
    b.year;

-- Show yearly debt with 3-year moving average

SELECT
    b.year,
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt,
    AVG(SUM(b.amount)) OVER (
        PARTITION BY b.debtor_id
        ORDER BY b.year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3yr
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.year,
    b.debtor_id,
    d.debtor_country_name
ORDER BY
    d.debtor_country_name,
    b.year;

-- Show where each borrower's debt stands as a percentage compared to others

SELECT
    b.year,
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt,
    PERCENT_RANK() OVER (
        PARTITION BY b.year
        ORDER BY SUM(b.amount) ASC
    ) AS debt_percentile
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.year,
    b.debtor_id,
    d.debtor_country_name
ORDER BY
    b.year,
    debt_percentile DESC;

-- Show yearly debt and change compared to previous year

SELECT
    b.year,
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt,
    SUM(b.amount) - LAG(SUM(b.amount)) OVER (
        PARTITION BY b.debtor_id
        ORDER BY b.year
    ) AS debt_change_from_prev_year
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.year,
    b.debtor_id,
    d.debtor_country_name
ORDER BY
    d.debtor_country_name,
    b.year;

-- Find countries with debt above overall average

SELECT
    debtor_id,
    SUM(amount) AS yearly_debt
FROM
    bilateral_debt_table
GROUP BY
    debtor_id
HAVING
    SUM(amount) > (SELECT AVG(amount) FROM bilateral_debt_table)
ORDER BY
    yearly_debt DESC;


-- Show all countries except the top borrower

SELECT
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.debtor_id,
    d.debtor_country_name
HAVING
    b.debtor_id NOT IN (
        -- Subquery to find the top borrower
        SELECT debtor_id
        FROM bilateral_debt_table
        GROUP BY debtor_id
        ORDER BY SUM(amount) DESC
        LIMIT 1
    )
ORDER BY
    yearly_debt DESC;
	
-- Compare each country's debt with average debt in that year

SELECT
    b.year,
    d.debtor_country_name AS borrower_country,
    SUM(b.amount) AS yearly_debt
FROM
    bilateral_debt_table b
JOIN
    debtor_country_table d
ON
    b.debtor_id = d.debtor_id
GROUP BY
    b.year,
    b.debtor_id,
    d.debtor_country_name
HAVING
    SUM(b.amount) > (
        SELECT AVG(amount)
        FROM bilateral_debt_table
        WHERE year = b.year
    )
ORDER BY
    b.year,
    yearly_debt DESC;

-- Countries with positive debt growth (safe from division by zero)
WITH yearly_debt AS (
    SELECT
        b.year,
        d.debtor_country_name AS borrower_country,
        SUM(b.amount) AS total_debt,
        LAG(SUM(b.amount)) OVER (
            PARTITION BY b.debtor_id
            ORDER BY b.year
        ) AS prev_year_debt
    FROM
        bilateral_debt_table b
    JOIN
        debtor_country_table d
    ON
        b.debtor_id = d.debtor_id
    GROUP BY
        b.year,
        b.debtor_id,
        d.debtor_country_name
)
SELECT
    year,
    borrower_country,
    total_debt,
    prev_year_debt,
    ROUND(((total_debt - prev_year_debt) / prev_year_debt) * 100, 2) AS growth_percent
FROM
    yearly_debt
WHERE
    prev_year_debt IS NOT NULL
    AND prev_year_debt <> 0
    AND (total_debt - prev_year_debt) > 0
ORDER BY
    growth_percent DESC;
	

-- Show debt growth rates per country per year


WITH yearly_debt AS (
    SELECT
        b.year,
        d.debtor_country_name AS borrower_country,
        SUM(b.amount) AS total_debt,
        LAG(SUM(b.amount)) OVER (
            PARTITION BY b.debtor_id
            ORDER BY b.year
        ) AS prev_year_debt
    FROM
        bilateral_debt_table b
    JOIN
        debtor_country_table d
    ON
        b.debtor_id = d.debtor_id
    GROUP BY
        b.year,
        b.debtor_id,
        d.debtor_country_name
)
SELECT
    year,
    borrower_country,
    total_debt,
    prev_year_debt,
    CASE 
        WHEN prev_year_debt IS NULL OR prev_year_debt = 0 THEN NULL
        ELSE ROUND(((total_debt - prev_year_debt) / prev_year_debt) * 100, 2)
    END AS growth_percent
FROM
    yearly_debt
ORDER BY
    borrower_country,
    year;
