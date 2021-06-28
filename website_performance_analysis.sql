USE asahitoystore;

/* 
Finding Top Website Pages
*/

SELECT	
	pageview_url,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_pageviews
WHERE created_at < '2012-06-09'
GROUP BY 1
ORDER BY 2 DESC;

/* 
Finding Top Entry Pages
*/

-- STEP 1: find the first pageview for each session
-- STEP 2: find the url the customer saw on that first page

CREATE TEMPORARY TABLE first_pageview;
SELECT	
	website_session_id,
    MIN(website_pageview_id) AS min_pageview_id
FROM website_pageviews
GROUP BY 1;

SELECT
	website_pageviews.pageview_url AS landing_page,
    COUNT(DISTINCT first_pageview.website_session_id) AS sessions_hitting_this_lander
FROM first_pageview
	LEFT JOIN website_pageviews
		ON first_pageview.min_pageview_id = website_pageviews.website_pageview_id
GROUP BY 1;

/* 
Calculating Bounce Rates
*/

-- STEP 1: finding the first pageview_id for relevant session
-- STEP 2: identifying the landing page of each session
-- STEP 3: counting pageviews for each sessions, to identify "bounces"
-- STEP 4: summarizing by counting total sessions and bounced sessions

CREATE TEMPORARY TABLE first_pageviews;
SELECT	
	website_session_id,
    MIN(website_pageview_id) AS min_pageview_id
FROM website_pageviews
WHERE created_at < '2012-06-14'
GROUP BY 1;

-- next, we'll bring in the landing page but restict to home only

CREATE TEMPORARY TABLE sessions_with_home_landing_page;
SELECT
	first_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_pageviews
	LEFT JOIN website_pageviews
		ON first_pageviews.min_pageview_id = website_pageviews.website_pageview_id
WHERE website_pageviews.pageview_url = '/home';

-- then a table to have count of pageview per session
	-- then limit it to just bounced_sessions
    
CREATE TEMPORARY TABLE bounced_sessions;
SELECT
	sessions_with_home_landing_page.website_session_id,
    sessions_with_home_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pageviews
FROM sessions_with_home_landing_page
	LEFT JOIN website_pageviews
		ON sessions_with_home_landing_page.website_session_id = website_pageviews.website_session_id
GROUP BY 1,2
HAVING 
	COUNT(website_pageviews.website_pageview_id) = 1;
    
-- final output for calculating Bounce Rates

SELECT
	COUNT(DISTINCT sessions_with_home_landing_page.website_session_id) AS total_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT bounced_sessions.website_session_id) / COUNT(DISTINCT sessions_with_home_landing_page.website_session_id) AS bounce_rate
FROM sessions_with_home_landing_page
	LEFT JOIN bounced_sessions
		ON sessions_with_home_landing_page.website_session_id = bounced_sessions.website_session_id;

/* 
Analyzing Landing Page Tests
*/

-- STEP 0: finding out when the new page /lander launched
-- STEP 1: finding the first website_pageview_id for relevant sessions
-- STEP 2: identifying the landing page of each session
-- STEP 3: counting pageviews for each sessions, to identify "bounces"
-- STEP 4: summarizing by counting total sessions and bounced sessions

SELECT
	MIN(created_at) AS first_created_at,
    MIN(website_pageview_id) AS first_pageview_id
FROM website_pageviews
WHERE pageview_url = '/lander-1'
	AND created_at IS NOT NULL;

-- first_created_at = '2012-06-19 00:35:54'
-- first_pageview_id = 23504

CREATE TEMPORARY TABLE first_test_pageviews;
SELECT	
	website_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_pageview_id
FROM website_pageviews
	INNER JOIN website_sessions
		ON website_pageviews.website_session_id = website_sessions.website_session_id
        AND website_sessions.created_at < '2012-07-28'
        AND website_pageviews.website_pageview_id > 23504
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 1;

-- next, we'll bring in the landing page to each session, but resticting to home or lander-1

CREATE TEMPORARY TABLE nonbrand_test_sessions_with_landing_page;
SELECT
	first_test_pageviews.website_session_id,
    website_pageviews.pageview_url AS landing_page
FROM first_test_pageviews
	LEFT JOIN website_pageviews
		ON first_test_pageviews.min_pageview_id = website_pageviews.website_pageview_id
WHERE website_pageviews.pageview_url IN ('/home', '/lander-1');

-- then a table to have count of pageviews per session
	-- then limit it to just bounced_sessions

CREATE TEMPORARY TABLE nonbrand_test_bounced_sessions;
SELECT
	nonbrand_test_sessions_with_landing_page.website_session_id,
    nonbrand_test_sessions_with_landing_page.landing_page,
    COUNT(website_pageviews.website_pageview_id) AS count_of_pageviews
FROM nonbrand_test_sessions_with_landing_page
	LEFT JOIN website_pageviews
		ON nonbrand_test_sessions_with_landing_page.website_session_id = website_pageviews.website_session_id
GROUP BY 1,2
HAVING
	COUNT(website_pageviews.website_pageview_id) = 1;
    
-- final output for Analyzing Landing Page Tests

SELECT
	nonbrand_test_sessions_with_landing_page.landing_page,
    COUNT(DISTINCT nonbrand_test_sessions_with_landing_page.website_session_id) AS sessions,
    COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id) AS bounced_sessions,
	COUNT(DISTINCT nonbrand_test_bounced_sessions.website_session_id) / COUNT(DISTINCT nonbrand_test_sessions_with_landing_page.website_session_id) AS bounce_tates
FROM nonbrand_test_sessions_with_landing_page
	LEFT JOIN nonbrand_test_bounced_sessions
		ON nonbrand_test_sessions_with_landing_page.website_session_id = nonbrand_test_bounced_sessions.website_session_id
GROUP BY 1;

/* 
Landing Page Trend Analysis
*/

-- STEP 1: finding the first website_pageview_id for relevant sessions
-- STEP 2: identifying the landing page of each session
-- STEP 3: counting pageviews for each session, to identify "bounces"
-- STEP 4: summarizing by week (bounce rate, session to each lander)

CREATE TEMPORARY TABLE sessions_with_min_pageview_id_and_view_count;
SELECT
	website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pageview_id,
    COUNT(website_pageviews.website_pageview_id) AS count_pageviews
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = website_sessions.website_session_id
        AND website_sessions.created_at > '2012-06-01'
        AND website_sessions.created_at < '2012-08-31'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY 1;

CREATE TEMPORARY TABLE sessions_with_counts_lander_and_created_at;
SELECT
	sessions_with_min_pageview_id_and_view_count.website_session_id,
    sessions_with_min_pageview_id_and_view_count.first_pageview_id,
    sessions_with_min_pageview_id_and_view_count.count_pageviews,
    website_pageviews.pageview_url AS landing_page,
    website_pageviews.created_at AS session_created_at
FROM sessions_with_min_pageview_id_and_view_count
	LEFT JOIN website_pageviews
		ON sessions_with_min_pageview_id_and_view_count.first_pageview_id = website_pageviews.website_pageview_id;

SELECT	
	YEARWEEK(session_created_at) AS year_week,
    MIN(DATE(session_created_at)) AS week_start_date,
    COUNT(DISTINCT website_session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END) AS bounce_sessions,
    COUNT(DISTINCT CASE WHEN count_pageviews = 1 THEN website_session_id ELSE NULL END) * 1.0 / COUNT(DISTINCT website_session_id) AS bounce_rate,
	COUNT(DISTINCT CASE WHEN landing_page = '/home' THEN website_session_id ELSE NULL END) AS home_sessions,
	COUNT(DISTINCT CASE WHEN count_pageviews = '/lander-1' THEN website_session_id ELSE NULL END) AS lander_sessions
FROM sessions_with_counts_lander_and_created_at
GROUP BY 1;


-- Demo on Building Conversion Funnels

-- Business Context
	-- we want to build a mini conversion funnel, from lander-2 to /cart
    -- we want to know how many people reach each step, and also dropoff rate
    -- for simplicity of the demo, we're looking at /lander-2 traffic only
    -- for simplicity of the demo, we're looking at customers who like Mr Fuzzy only

-- STEP 1: select all pageviews for relevant sessions
-- STEP 2: identify each relevant pageview as the specific funnel step
-- STEP 3: create the session-level conversion funnel view
-- STEP 4: aggregate the data to access funnel performance

-- first find all of the pageviews we care about

/*
this query will be put in the next query as a sub-query

SELECT
	tb1.website_session_id,
    tb2.pageview_url,
    tb2.created_at AS pageview_created_at,
    CASE WHEN tb2.pageview_url = '/lander-2' THEN 1 ELSE NULL END AS lander2_page,
    CASE WHEN tb2.pageview_url = '/products' THEN 1 ELSE NULL END AS product_page,
    CASE WHEN tb2.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE NULL END AS mrfuzzy_page,
    CASE WHEN tb2.pageview_url = '/cart' THEN 1 ELSE NULL END AS cart_page
FROM website_sessions as tb1
	LEFT JOIN website_pageviews as tb2
		ON tb1.website_session_id = tb2.website_session_id
WHERE tb1.created_at BETWEEN '2014-01-01' AND '2014-02-01' -- random timeframe for demo
	AND tb2.pageview_url IN ('/lander-2', '/products', '/the-original-mr-fuzzy', '/cart')
ORDER BY 1,3;
*/

-- we will group by website_session_id and take the MAX() of each of the flag
-- this MAX() becomes a made_it flag for that session, to show the session made it there

CREATE TEMPORARY TABLE session_level_made_it_flags_demo;
SELECT
	website_session_id,
    MAX(lander2_page) AS lander2_made_it,
    MAX(product_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it
FROM(
SELECT
	tb1.website_session_id,
    tb2.pageview_url,
    tb2.created_at AS pageview_created_at,
    CASE WHEN tb2.pageview_url = '/lander-2' THEN 1 ELSE NULL END AS lander2_page,
    CASE WHEN tb2.pageview_url = '/products' THEN 1 ELSE NULL END AS product_page,
    CASE WHEN tb2.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE NULL END AS mrfuzzy_page,
    CASE WHEN tb2.pageview_url = '/cart' THEN 1 ELSE NULL END AS cart_page
FROM website_sessions as tb1
	LEFT JOIN website_pageviews as tb2
		ON tb1.website_session_id = tb2.website_session_id
WHERE tb1.created_at BETWEEN '2014-01-01' AND '2014-02-01' -- random timeframe for demo
	AND tb2.pageview_url IN ('/lander-2', '/products', '/the-original-mr-fuzzy', '/cart')
ORDER BY 1,3
) AS pageview_level
GROUP BY 1;

-- this would product the final ouput (part-1)

SELECT
	COUNT(DISTINCT website_session_id) AS sessions,
	COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart
FROM session_level_made_it_flags_demo;

-- this would product the final ouput (part-2)

SELECT
	COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT website_session_id) AS clicked_to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS clicked_to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS clicked_to_cart
FROM session_level_made_it_flags_demo;

/* 
Building Conversion Funnels
*/

-- STEP 1: select all pageviews for relevant sessions
-- STEP 2: identify each pageview as the specific funnel step
-- STEP 3: create the session-level conversion funnel view
-- STEP 4: aggregate the data to access funnel performance

/*
this query will be put in the next query as a sub-query

SELECT
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
	AND website_sessions.utm_campaign = 'nonbrand'
    AND website_sessions.created_at > '2012-08-05'
    AND website_sessions.created_at < '2012-09-05'
ORDER BY 1;
*/

CREATE TEMPORARY TABLE session_level_made_it_flags;
SELECT
	website_session_id,
    MAX(product_page) AS product_made_it,
    MAX(mrfuzzy_page) AS mrfuzzy_made_it,
    MAX(cart_page) AS cart_made_it,
    MAX(shipping_page) AS shipping_made_it,
    MAX(billing_page) AS billing_made_it,
    MAX(thankyou_page) AS thankyou_made_it
FROM(
SELECT
	website_sessions.website_session_id,
    website_pageviews.pageview_url,
    CASE WHEN pageview_url = '/products' THEN 1 ELSE 0 END AS product_page,
    CASE WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END AS mrfuzzy_page,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.utm_source = 'gsearch'
	AND website_sessions.utm_campaign = 'nonbrand'
    AND website_sessions.created_at > '2012-08-05'
    AND website_sessions.created_at < '2012-09-05'
ORDER BY 1
) AS pageview_level
GROUP BY 1;

-- this would product final output (part-1)

SELECT
	COUNT(DISTINCT website_session_id) AS sessions,
	COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS to_products,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM session_level_made_it_flags;

-- this would product final output (part-2)

SELECT
	COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT website_session_id) AS lander_click_rt,
    COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END)
		/ COUNT(DISTINCT CASE WHEN product_made_it = 1 THEN website_session_id ELSE NULL END) AS products_click_rt,
    COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN mrfuzzy_made_it = 1 THEN website_session_id ELSE NULL END) AS mrfuzzy_click_rt,
    COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN cart_made_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
    COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN shipping_made_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rt,
    COUNT(DISTINCT CASE WHEN thankyou_made_it = 1 THEN website_session_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN billing_made_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt
FROM session_level_made_it_flags;

/* 
Analyzing Conversion Funnel Tests
*/

-- first, finding the starting point to frame the analysis

SELECT
	MIN(website_pageviews.website_pageview_id) AS first_pageview_id
FROM website_pageviews
WHERE pageview_url = '/billing-2';

-- we get first_pageview_id = 53550

/*
this query will be put in the next query as a sub-query

SELECT
	website_pageviews.website_session_id,
    website_pageviews.pageview_url AS billing_version_seen,
    orders.order_id
FROM website_pageviews
	LEFT JOIN orders
		ON website_pageviews.website_session_id = orders.website_session_id
WHERE website_pageviews.website_pageview_id >= 53550
	AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing', '/billing-2');
*/

-- final analysis output

SELECT
	billing_version_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) AS billing_to_order_rt
FROM(
SELECT
	website_pageviews.website_session_id,
    website_pageviews.pageview_url AS billing_version_seen,
    orders.order_id
FROM website_pageviews
	LEFT JOIN orders
		ON website_pageviews.website_session_id = orders.website_session_id
WHERE website_pageviews.website_pageview_id >= 53550
	AND website_pageviews.created_at < '2012-11-10'
    AND website_pageviews.pageview_url IN ('/billing', '/billing-2')
) AS billing_sessions_with_orders
GROUP BY 1;

	
