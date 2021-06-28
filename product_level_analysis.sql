USE asahitoystore;
SHOW tables;

/* 
Calculate Orders, Revenues, Margin and AOV according to the Primary Product
*/

SELECT 
	primary_product_id,
	COUNT(order_id) as orders,
    SUM(price_usd) as revenues,
    SUM(price_usd - cogs_usd) as margin,
    AVG(price_usd) as average_order_value
FROM orders
GROUP BY 1
ORDER BY 2 DESC;

/* 
Product-Level Sales Analysis
*/

SELECT
	YEAR(created_at) as year,
    month(created_at) as month,
    COUNT(order_id) as total_orders,
    SUM(price_usd) as total_revenues,
    SUM(price_usd - cogs_usd) as total_margin
FROM orders
where created_at <= '2013-01-04'
GROUP BY 1,2;
  
/* 
Product Launch Sales Analysis 
*/

SELECT
	YEAR(website_sessions.created_at) as year,
    MONTH(website_sessions.created_at) as month,
    COUNT(DISTINCT website_sessions.website_session_id) as sessions,
    COUNT(DISTINCT orders.order_id) as orders,
    COUNT(DISTINCT orders.order_id)/ COUNT(DISTINCT website_sessions.website_session_id) as conversion_rates,
    SUM(price_usd)/ COUNT(DISTINCT website_sessions.website_session_id) as revenue_per_session
FROM website_sessions
	left join orders 
		on website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at between '2012-04-01' and '2013-04-05'
GROUP BY 1,2
ORDER BY 5 DESC;

/* 
Product-Level Website Pathing 
*/

-- Step 1: finding the /products pageviews we care about
CREATE TEMPORARY TABLE products_pageviews;
SELECT 
	website_session_id,
    website_pageview_id,
    created_at,
    CASE 
		WHEN created_at < '2013-01-06' THEN 'A. Pre_New_Product_Launch' 
        WHEN created_at >= '2013-01-06' THEN 'B. Post_New_Product_Launch'
        ELSE 'oh oh...'
	END AS time_period
FROM website_pageviews
WHERE created_at < '2013-04-06'
	AND created_at > '2012-10-06'
    AND pageview_url = '/products';

-- Step 2: finding the next pageview id that occurs after the product pageview
CREATE TEMPORARY TABLE next_pageview_id;
SELECT 
	products_pageviews.time_period,
    products_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS next_pageview_id
FROM products_pageviews
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = products_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id
GROUP BY 1,2;

-- Step 3: find the pageview_url associated with any appliciable next pageview id
CREATE TEMPORARY TABLE next_pageview_url;
SELECT
	next_pageview_id.time_period,
    next_pageview_id.website_session_id,
    website_pageviews.pageview_url as next_pageview_url
FROM next_pageview_id
	LEFT JOIN website_pageviews
        ON next_pageview_id.next_pageview_id = website_pageviews.website_pageview_id;

-- Step 4: summarize the data and analyze the pre and post periods
SELECT
	time_period,
    COUNT(website_session_id) as sessions,
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NUll END) AS next_page_session,
    COUNT(DISTINCT CASE WHEN next_pageview_url IS NOT NULL THEN website_session_id ELSE NUll END) / COUNT(website_session_id) AS next_page_session_percentage,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NUll END) AS to_mrfuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NUll END) / COUNT(website_session_id) AS to_mrfuzzy_percentage,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NUll END) AS to_lovebear,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NUll END) / COUNT(website_session_id) AS to_lovebear_percentage
FROM next_pageview_url
GROUP BY time_period;

/* 
Building Product Conversion Funnels
*/

-- SETP 1: select all pageviews for relevant sessions
-- SETP 2: figure out which pageview urls to look for 
-- SETP 3: pull all pageviews and identify the funnel
-- SETP 4: create the session-level conversion funnel
-- SETP 5: aggregate the data to access funnel performance

CREATE TEMPORARY TABLE sessions_seeing_mrfuzzy_and_lovebear;
SELECT
	website_session_id,
    website_pageview_id,
    pageview_url AS product_page_seen
FROM website_pageviews
WHERE created_at < '2013-04-10' 
	AND created_at > '2013-01-06' 
	AND pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear');

-- finding the right pageview_url to build the funnels
SELECT DISTINCT
	website_pageviews.pageview_url
FROM sessions_seeing_mrfuzzy_and_lovebear
	LEFT JOIN website_pageviews
		ON sessions_seeing_mrfuzzy_and_lovebear.website_session_id = website_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > sessions_seeing_mrfuzzy_and_lovebear.website_pageview_id;
        
-- we'll look at the inner query first to look over the pageview-level results
-- then, turn it into a subquery and make it summary with flags
SELECT
	sessions_seeing_mrfuzzy_and_lovebear.website_session_id,
    sessions_seeing_mrfuzzy_and_lovebear.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
	CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
	CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
	CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_mrfuzzy_and_lovebear
	LEFT JOIN website_pageviews
		ON sessions_seeing_mrfuzzy_and_lovebear.website_session_id = website_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > sessions_seeing_mrfuzzy_and_lovebear.website_pageview_id
ORDER BY
	sessions_seeing_mrfuzzy_and_lovebear.website_session_id,
    website_pageviews.created_at;
    
CREATE TEMPORARY TABLE sessions_product_level_make_it_flags;
SELECT
	website_session_id,
    CASE 
		WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
        WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
		ELSE 'uh oh ... Check Logic'
	END AS product_seen,
    MAX(cart_page) AS cart_make_it,
    MAX(shipping_page) AS shipping_make_it,
    MAX(billing_page) AS billing_make_it,
    MAX(thankyou_page) AS thankyou_make_it
FROM(
SELECT
	sessions_seeing_mrfuzzy_and_lovebear.website_session_id,
    sessions_seeing_mrfuzzy_and_lovebear.product_page_seen,
    CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
	CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
	CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
	CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
FROM sessions_seeing_mrfuzzy_and_lovebear
	LEFT JOIN website_pageviews
		ON sessions_seeing_mrfuzzy_and_lovebear.website_session_id = website_pageviews.website_session_id
        AND website_pageviews.website_pageview_id > sessions_seeing_mrfuzzy_and_lovebear.website_pageview_id
ORDER BY
	sessions_seeing_mrfuzzy_and_lovebear.website_session_id,
    website_pageviews.created_at
) AS pageview_level
GROUP BY 
	website_session_id,
    CASE
		WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
        WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
		ELSE 'uh oh ... Check Logic'
	END;
    
-- final output part 1
SELECT
	product_seen,
    COUNT(DISTINCT website_session_id) AS sessions,
    COUNT(DISTINCT CASE WHEN cart_make_it = 1 THEN website_session_id ELSE NULL END) AS to_cart,
    COUNT(DISTINCT CASE WHEN shipping_make_it = 1 THEN website_session_id ELSE NULL END) AS to_shipping,
    COUNT(DISTINCT CASE WHEN billing_make_it = 1 THEN website_session_id ELSE NULL END) AS to_billing,
    COUNT(DISTINCT CASE WHEN thankyou_make_it = 1 THEN website_session_id ELSE NULL END) AS to_thankyou
FROM sessions_product_level_make_it_flags
GROUP BY product_seen;
    
-- then this is final output part 2 - click rates
SELECT
	product_seen,
    COUNT(DISTINCT CASE WHEN cart_make_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT website_session_id) AS product_page_click_rt,
    COUNT(DISTINCT CASE WHEN shipping_make_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN cart_make_it = 1 THEN website_session_id ELSE NULL END) AS cart_click_rt,
    COUNT(DISTINCT CASE WHEN billing_make_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN shipping_make_it = 1 THEN website_session_id ELSE NULL END) AS shipping_click_rt,
    COUNT(DISTINCT CASE WHEN thankyou_make_it = 1 THEN website_session_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN billing_make_it = 1 THEN website_session_id ELSE NULL END) AS billing_click_rt
FROM sessions_product_level_make_it_flags
GROUP BY product_seen;


/* 
Cross-Selling Analysis 
*/

SELECT 	
	order_item_id,
    order_items.order_id,
    order_items.product_id,
    orders.primary_product_id,
    order_items.is_primary_item,
    orders.items_purchased
FROM orders 
	LEFT JOIN order_items
		on orders.order_id = order_items.order_id
WHERE items_purchased = 1 and is_primary_item = 1;
    
SELECT
	orders.primary_product_id,
    order_items.product_id,
    COUNT(orders.order_id) as orders
FROM orders
	LEFT JOIN order_items
		on orders.order_id = order_items.order_id
WHERE orders.order_id BETWEEN 10000 AND 11000
	AND orders.primary_product_id <> order_items.product_id
GROUP BY 1,2
ORDER BY 3 DESC;

SELECT
	orders.primary_product_id,
    COUNT(orders.order_id) as orders,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_item_id ELSE NULL END) as x_sell_product1,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN order_item_id ELSE NULL END) as x_sell_product2,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN order_item_id ELSE NULL END) as x_sell_product3,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_item_id ELSE NULL END) / COUNT(orders.order_id) as x_sell_product1_rt,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN order_item_id ELSE NULL END) / COUNT(orders.order_id) as x_sell_product2_rt,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN order_item_id ELSE NULL END) / COUNT(orders.order_id) as x_sell_product3_rt
FROM orders
	LEFT JOIN order_items
		ON orders.order_id = order_items.order_id
        AND order_items.is_primary_item = 0
where orders.order_id between 10000 and 11000
group by 1;

/* 
Cross-Selling Performance
*/

-- Step 1: Identify the relevant /cart page views and sessions
-- Step 2: See which of those /cart sessions clicked through to the shopping page
-- Step 3: Find the orders associated with the /cart sessions. Analyze products purchased. AOV.
-- Step 4: Aggregate and analyze a summary of our findings.

CREATE TEMPORARY TABLE session_seeing_cart;
SELECT
	CASE
		WHEN created_at < '2013-09-25' THEN 'A. Pre_Cross_Sell'
		WHEN created_at >= '2013-01-06' THEN 'A. Post_Cross_Sell'
        ELSE 'oh...check logic!'
	END AS time_period,
    created_at,
	website_session_id AS cart_session_id,
    website_pageview_id AS cart_pageview_id
FROM website_pageviews
WHERE created_at BETWEEN '2013-08-25' and '2013-10-25'
	AND pageview_url = '/cart';

CREATE TEMPORARY TABLE cart_session_seeing_another_page;
SELECT
	session_seeing_cart.time_period,
    session_seeing_cart.cart_session_id,
    MIN(website_pageviews.website_pageview_id) as cart_next_pageview_id
FROM session_seeing_cart
	LEFT JOIN website_pageviews
		ON session_seeing_cart.cart_session_id = website_pageviews.website_session_id
        AND	website_pageviews.website_pageview_id > session_seeing_cart.cart_pageview_id
GROUP BY 1,2
HAVING 
	MIN(website_pageviews.website_pageview_id) IS NOT NULL;
    
CREATE TEMPORARY TABLE pre_post_sessions_orders;
SELECT 
	time_period,
    cart_session_id,
    order_id,
    items_purchased,
    price_usd
FROM session_seeing_cart
	LEFT JOIN orders
		ON session_seeing_cart.cart_session_id = orders.website_session_id;

SELECT
	time_period,
    COUNT(DISTINCT cart_session_id) AS cart_sessions,
    SUM(clicked_to_another_page) AS clickthrough,
    SUM(clicked_to_another_page) / COUNT(DISTINCT cart_session_id) AS cart_ctr,
    SUM(placed_order) AS orders_placed,
    SUM(items_purchased) AS products_purchased,
    SUM(items_purchased) / SUM(placed_order) AS products_per_order,
    SUM(price_usd) AS revenue,
    SUM(price_usd) / SUM(placed_order) AS aov,
    SUM(price_usd) / COUNT(DISTINCT cart_session_id) AS rev_per_cart_session
FROM (
SELECT
	session_seeing_cart.time_period,
	session_seeing_cart.cart_session_id,
    CASE WHEN cart_session_seeing_another_page.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
    CASE WHEN pre_post_sessions_orders.order_id IS NULL THEN 0 ELSE 1 END AS placed_order,
    pre_post_sessions_orders.items_purchased,
    pre_post_sessions_orders.price_usd
FROM session_seeing_cart
	LEFT JOIN cart_session_seeing_another_page
		ON session_seeing_cart.cart_session_id = cart_session_seeing_another_page.cart_session_id
	LEFT JOIN pre_post_sessions_orders
		ON cart_session_seeing_another_page.cart_session_id = pre_post_sessions_orders.cart_session_id
ORDER BY cart_session_id
) AS full_data
GROUP BY time_period;

/* 
Product Portfolio Expansion
*/

SELECT
	CASE 
		WHEN website_sessions.created_at < '2013-12-12' THEN 'A. Pre_Birthday_Bear'
        WHEN website_sessions.created_at >= '2013-12-12' THEN 'B. Post_Birthday_Bear'
		ELSE 'uh oh...check logic'
	END AS time_period,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS conversion_rt,
    SUM(orders.price_usd) AS total_revenue,
    SUM(orders.items_purchased) AS total_product_sold,
    SUM(orders.price_usd) / COUNT(DISTINCT orders.order_id) AS avg_order_value,
	SUM(orders.items_purchased) / COUNT(DISTINCT orders.order_id) AS products_per_order,
    SUM(orders.price_usd) / COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at BETWEEN '2013-11-12' AND '2014--1-12'
GROUP BY 1;

/*
Product Refund Rates Analysis
*/

show columns from order_items;
SELECT
	order_items.order_id,
    order_items.order_item_id,
    order_items.price_usd as price_paid_usd,
    order_items.created_at,
    order_item_refunds.order_item_refund_id,
    order_item_refunds.refund_amount_usd,
    order_item_refunds.created_at
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_item_refunds.order_item_id = order_items.order_item_id
WHERE order_items.order_id IN (3489, 27061, 32049);
    
/*
Product Refund Rates Analysis
*/

SELECT
	YEAR(order_items.created_at) AS year,
    MONTH(order_items.created_at) AS month,
    COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_orders,
    COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_item_refunds.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_orders,
    COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_item_refunds.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_orders,
    COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_item_refunds.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_refund_rt,
	COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_orders,
    COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_item_refunds.order_item_id ELSE NULL END) 
		/ COUNT(DISTINCT CASE WHEN product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_refund_rt
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
WHERE order_items.created_at < '2014-10-15'
GROUP BY 1,2;
    
SELECT
	YEAR(order_items.created_at) as year,
    MONTH(order_items.created_at) as month,
    COUNT(DISTINCT order_items.order_item_id) as order_items,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_orders,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_orders,
	COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_orders,
	COUNT(DISTINCT CASE WHEN order_items.product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_orders,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_item_refunds.order_item_refund_id ELSE NULL END) as p1_refund,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_item_refunds.order_item_refund_id ELSE NULL END) / COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_refund_rt,
    COUNT(DISTINCT order_item_refunds.order_item_refund_id) as refunds
FROM  order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
WHERE 
	order_items.created_at BETWEEN '2013-09-30' AND '2014-10-15'
GROUP BY 1,2;

--
CREATE TEMPORARY TABLE product_refund;
SELECT
	YEAR(order_items.created_at) as year,
    MONTH(order_items.created_at) as month,
	count(order_item_refunds.order_item_refund_id) refunds
FROM order_item_refunds
	INNER JOIN order_items
		ON order_item_refunds.order_item_id = order_items.order_item_id
WHERE 
	order_items.created_at BETWEEN '2013-09-30' AND '2014-10-15'
    AND product_id = 1
GROUP BY 1,2;




    
    

