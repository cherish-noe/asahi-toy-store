USE asahitoystore;

/* 
Analyzing Seasonality
*/

-- output_1
SELECT
	YEAR(website_sessions.created_at) AS year,
    MONTH(website_sessions.created_at) AS month,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions	
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2013-01-01'
GROUP BY 1,2;

-- output_2
SELECT
	YEAR(website_sessions.created_at) AS year,
    WEEK(website_sessions.created_at) AS week,
    MIN(DATE(website_sessions.created_at)) AS week_start,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders
FROM website_sessions	
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < '2013-01-01'
GROUP BY 1,2;

/* 
Analyzing Business Patterns
*/

/*
this query is added to another query as sub-query

CREATE TEMPORARY TABLE temp_tb;
SELECT
	DATE(created_at) AS created_date,
    WEEKDAY(created_at) AS week_day, -- 0 = Monday, 6 = Sunday
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1,2,3;
*/
    
SELECT
	hr,
    ROUND(AVG(sessions),1) AS avg_sessions,
    ROUND(AVG(CASE WHEN week_day = 0 THEN sessions ELSE NULL END),1) AS mon,
    ROUND(AVG(CASE WHEN week_day = 1 THEN sessions ELSE NULL END),1) AS tue,
    ROUND(AVG(CASE WHEN week_day = 2 THEN sessions ELSE NULL END),1) AS wed,
    ROUND(AVG(CASE WHEN week_day = 3 THEN sessions ELSE NULL END),1) AS thur,
    ROUND(AVG(CASE WHEN week_day = 4 THEN sessions ELSE NULL END),1) AS fri,
    ROUND(AVG(CASE WHEN week_day = 5 THEN sessions ELSE NULL END),1) AS sat,
    ROUND(AVG(CASE WHEN week_day = 6 THEN sessions ELSE NULL END),1) AS sun
FROM(
SELECT
	DATE(created_at) AS created_date,
    WEEKDAY(created_at) AS week_day, -- 0 = Monday, 6 = Sunday
    HOUR(created_at) AS hr,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
WHERE created_at BETWEEN '2012-09-15' AND '2012-11-15'
GROUP BY 1,2,3
) AS daily_hourly_sessions
GROUP BY 1;
    

