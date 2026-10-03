/*
===============================================================================
Script Name : Procedure_Load_Silver.sql
Layer       : Silver (cleansed / standardized)
Database    : DataWarehouse (SQL Server)
===============================================================================
PURPOSE
    Loads the Silver layer tables from the Bronze layer (raw source data).
    While loading, the script cleans and standardizes the data:
        - Removes duplicates and NULL keys
        - Trims text and normalizes coded values (e.g. 'M' -> 'Married')
        - Fixes invalid dates and recalculates inconsistent sales / price values
        - Derives new columns (e.g. category ID, product end date)

    Tables loaded (Bronze -> Silver):
        1. bronze.crm_cust_info     -> silver.crm_cust_info
        2. bronze.crm_prd_info      -> silver.crm_prd_info
        3. bronze.crm_sales_details -> silver.crm_sales_details
        4. bronze.erp_CUST_AZ12     -> silver.erp_CUST_AZ12
        5. bronze.erp_LOC_A101      -> silver.erp_LOC_A101
        6. bronze.erp_PX_CAT_G1V2   -> silver.erp_PX_CAT_G1V2

USAGE
    1. Make sure the Bronze tables are already loaded.
    2. Make sure the Silver tables already exist (created by the DDL script).
    3. Run the whole script in SSMS / Azure Data Studio:
           Execute this file (F5) against the DataWarehouse database.
    4. Validate the results, e.g.:
           SELECT COUNT(*) FROM silver.crm_cust_info;

WARNING
    *** FULL REFRESH ***  Each Silver table is TRUNCATED before it is loaded.
    All existing data in the Silver tables will be permanently deleted and
    replaced. Do not run this on a database whose Silver data you need to keep.
    The script has no transaction or error handling: if it fails midway, some
    tables may be empty or partially loaded. Re-run the full script to recover.
===============================================================================
*/

USE DataWarehouse;
GO
Create or Alter Procedure silver.load_procedure as 
BEGIN

        /* ============================================================================
           1. silver.crm_cust_info  (CRM customer master data)
           ============================================================================ */

        -- Empty the target table so the load is a clean full refresh
        TRUNCATE TABLE silver.crm_cust_info;
        

        INSERT INTO silver.crm_cust_info (
            cst_id, cst_key, cst_firstname, cst_lastname,
            cst_marital_status, cst_gndr, cst_create_date
        )
        SELECT
            cst_id,
            cst_key,

            -- Remove leading/trailing spaces from names
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname)  AS cst_lastname,

            -- Standardize marital status codes into readable values
            CASE WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
                 WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
                 ELSE 'n/a'                                   -- unknown / missing
            END AS cst_marital_status,

            -- Standardize gender codes into readable values
            CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
                 WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
                 ELSE 'n/a'                                   -- unknown / missing
            END AS cst_gndr,

            cst_create_date

        FROM (
            -- Rank records per customer, newest first (Flag_last = 1 is the latest)
            SELECT
                *,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS Flag_last
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL                          -- drop rows without a customer ID
        ) t
        WHERE Flag_last = 1;                                  -- keep only the latest record per customer
        


        /* ============================================================================
           2. silver.crm_prd_info  (CRM product master data)
           ============================================================================ */

        TRUNCATE TABLE silver.crm_prd_info;
        

        INSERT INTO silver.crm_prd_info (
            prd_id, prd_key, cat_ID, prd_nm,
            prd_cost, prd_line, prd_start_dt, prd_end_dt
        )
        SELECT
            [prd_id],

            -- Product key: everything after the first 6 characters of the raw key
            SUBSTRING(prd_key, 7, LEN(prd_key)) AS [prd_key],

            -- Category ID: first 5 characters of the raw key, '-' replaced with '_'
            REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS [cat_ID],

            [prd_nm],

            -- Replace missing cost with 0
            ISNULL([prd_cost], 0) AS [prd_cost],

            -- Convert product line codes into readable names
            CASE UPPER(TRIM([prd_line]))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Others'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'                                    -- unknown / missing
            END AS [prd_line],

            [prd_start_dt],

            -- End date = day before the next version's start date (same product).
            -- The latest version has no next row, so its end date stays NULL.
            DATEADD(
                DAY, -1,
                LEAD([prd_start_dt]) OVER (
                    PARTITION BY prd_key
                    ORDER BY prd_start_dt
                )
            ) AS [prd_end_dt]

        FROM [DataWarehouse].[bronze].[crm_prd_info];
        


        /* ============================================================================
           3. silver.crm_sales_details  (CRM sales transactions)
           ============================================================================ */

        TRUNCATE TABLE silver.crm_sales_details;
        

        INSERT INTO silver.crm_sales_details (
            sls_ord_num, sls_prd_key, sls_cust_id,
            sls_order_dt, sls_ship_dt, sls_due_dt,
            sls_sales, sls_quantity, sls_price
        )
        SELECT
            [sls_ord_num],
            [sls_prd_key],
            [sls_cust_id],

            -- Order date: dates are stored as YYYYMMDD integers in Bronze.
            -- If invalid (<= 0 or not 8 digits), estimate it as ship date - 7 days.
            CASE WHEN [sls_order_dt] <= 0 OR LEN([sls_order_dt]) != 8
                 THEN DATEADD(DAY, -7, CAST(CAST([sls_ship_dt] AS NVARCHAR) AS DATE))
                 ELSE CAST(CAST([sls_order_dt] AS NVARCHAR) AS DATE)
            END AS [sls_order_dt],

            -- Ship date: if invalid, estimate it as order date + 7 days
            CASE WHEN [sls_ship_dt] <= 0 OR LEN([sls_ship_dt]) != 8
                 THEN DATEADD(DAY, 7, CAST(CAST([sls_order_dt] AS NVARCHAR) AS DATE))
                 ELSE CAST(CAST([sls_ship_dt] AS NVARCHAR) AS DATE)
            END AS [sls_ship_dt],

            -- Due date: if invalid, estimate it as order date + 12 days
            CASE WHEN [sls_due_dt] <= 0 OR LEN([sls_due_dt]) != 8
                 THEN DATEADD(DAY, 12, CAST(CAST([sls_order_dt] AS NVARCHAR) AS DATE))
                 ELSE CAST(CAST([sls_due_dt] AS NVARCHAR) AS DATE)
            END AS [sls_due_dt],

            -- Sales: recalculate as quantity * price when it is missing, <= 0,
            -- or does not match quantity * price
            CASE WHEN [sls_sales] IS NULL
                      OR [sls_sales] <= 0
                      OR [sls_sales] != [sls_quantity] * ABS([sls_price])
                 THEN [sls_quantity] * ABS([sls_price])
                 ELSE [sls_sales]
            END AS [sls_sales],

            [sls_quantity],

            -- Price: if missing or <= 0, derive it as sales / quantity
            -- (NULLIF avoids a divide-by-zero error when quantity is 0)
            CASE WHEN [sls_price] IS NULL OR [sls_price] <= 0
                 THEN ABS([sls_Sales]) / NULLIF([sls_quantity], 0)
                 ELSE [sls_price]
            END AS [sls_price]

        FROM [DataWarehouse].[bronze].[crm_sales_details];
        


        /* ============================================================================
           4. silver.erp_CUST_AZ12  (ERP customer birthdate and gender)
           ============================================================================ */

        TRUNCATE TABLE silver.erp_CUST_AZ12;
        

        INSERT INTO silver.erp_CUST_AZ12 (CID, BDATE, GEN)
        SELECT
            -- Remove the 'NAS' prefix so the ID matches the CRM customer key
            CASE WHEN CID LIKE 'NAS%' THEN SUBSTRING(CID, 4, LEN(CID))
                 ELSE CID
            END AS [CID],

            -- Birthdates in the future are invalid, so set them to NULL
            CASE WHEN BDATE > GETDATE() THEN NULL
                 ELSE BDATE
            END AS [BDATE],

            -- Standardize gender values
            CASE WHEN UPPER(TRIM([GEN])) IN ('F', 'FEMALE') THEN 'Female'
                 WHEN UPPER(TRIM([GEN])) IN ('M', 'MALE')   THEN 'Male'
                 ELSE 'n\a'                                   -- unknown / missing
            END AS [GEN]

        FROM bronze.erp_CUST_AZ12;
        


        /* ============================================================================
           5. silver.erp_LOC_A101  (ERP customer country)
           ============================================================================ */

        TRUNCATE TABLE silver.erp_LOC_A101;
        

        INSERT INTO silver.erp_LOC_A101 (CID, CNTRY)
        SELECT
            -- Remove dashes so the ID matches the CRM customer key
            CASE WHEN CID LIKE '%-%' THEN REPLACE(CID, '-', '')
                 ELSE CID
            END AS [CID],

            -- Normalize country names / codes
            CASE WHEN UPPER(TRIM(CNTRY)) IS NULL OR CNTRY = '' THEN 'n\a'  -- missing or empty
                 WHEN UPPER(TRIM(CNTRY)) = 'DE'  THEN 'Germany'
                 WHEN UPPER(TRIM(CNTRY)) = 'USA' THEN 'United States'
                 WHEN UPPER(TRIM(CNTRY)) = 'US'  THEN 'United States'
                 ELSE TRIM(CNTRY)                             -- keep other values, just trimmed
            END AS [CNTRY]

        FROM bronze.erp_LOC_A101;
       


        /* ============================================================================
           6. silver.erp_PX_CAT_G1V2  (ERP product categories)
           ============================================================================ */

        TRUNCATE TABLE silver.erp_PX_CAT_G1V2;
        

        -- No transformation needed: data is already clean, so it is copied as-is
        INSERT INTO silver.erp_PX_CAT_G1V2 (ID, CAT, SUBCAT, MAINTENANCE)
        SELECT
            ID,
            CAT,
            SUBCAT,
            MAINTENANCE
        FROM bronze.erp_PX_CAT_G1V2;
END;
GO
