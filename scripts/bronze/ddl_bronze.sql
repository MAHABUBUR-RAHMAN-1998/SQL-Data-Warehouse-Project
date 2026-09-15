/* ==================================================================================
   Script Name : ddl_bronze.sql
   Layer       : Bronze (Raw Landing Layer)
   Purpose     : Creates the bronze layer tables in the DataWarehouse database.
                 These tables store raw, unprocessed data exactly as it arrives
                 from source systems (CRM and ERP), before any cleaning,
                 transformation, or business logic is applied.

   Sources     : CRM system  -> crm_cust_info, crm_prd_info, crm_sales_details
                 ERP system  -> erp_CUST_AZ12, erp_LOC_A101, erp_PX_CAT_G1V2

   Usage       : Run this script to (re)initialize the bronze schema tables
                 before loading raw data via the bronze load procedure.

   WARNING     : - This script DROPS existing tables in the bronze schema
                   before recreating them. Any data already loaded into these
                   tables WILL BE PERMANENTLY LOST.
                 - Ensure the bronze schema already exists in DataWarehouse
                   before running this script.
                 - Do NOT run this script directly against a production
                   environment without a verified backup.
================================================================================== */

USE DataWarehouse;
GO

-- ==============================================================================
-- Table: bronze.crm_cust_info
-- Purpose: Stores raw customer master data from the CRM system
-- ==============================================================================
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info
(
    cst_id              INT ,                        -- customer ID 
    cst_key             NVARCHAR(50),                -- Business/natural key used to match with other systems
    cst_firstname       NVARCHAR(50),                -- Customer first name
    cst_lastname        NVARCHAR(50),                -- Customer last name
    cst_marital_status  NVARCHAR(50),                -- Marital status (raw, unstandardized value from CRM)
    cst_gndr            NVARCHAR(15),                -- Gender (raw, unstandardized value from CRM)
    cst_create_date     DATE                         -- Date the customer record was created in CRM
);
GO

-- ==============================================================================
-- Table: bronze.crm_prd_info
-- Purpose: Stores raw product master data from the CRM system
-- ==============================================================================
DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info
(
    prd_id      INT  ,                      -- product ID (CRM  )
    prd_key     NVARCHAR(50),               -- Business/natural product key, used to link to sales & ERP category data
    prd_nm      NVARCHAR(50),               -- Product name
    prd_cost    FLOAT,                      -- Product cost
    prd_line    NVARCHAR(10),               -- Product line/category code
    prd_start_dt DATE,                      -- Date the product became active/available
    prd_end_dt  DATE                        -- Date the product was discontinued (NULL if still active)
);
GO

-- ==============================================================================
-- Table: bronze.crm_sales_details
-- Purpose: Stores raw sales transaction data from the CRM system
-- ==============================================================================
DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details
(
    sls_ord_num   NVARCHAR(50)  ,               -- Sales order number (  transaction identifier)
    sls_prd_key   NVARCHAR(50),              -- Product key sold, links to bronze.crm_prd_info.prd_key
    sls_cust_id   INT,                       -- Customer ID, links to bronze.crm_cust_info.cst_id
    sls_order_dt  INT,                      -- Date the order was placed
    sls_ship_dt   INT,                      -- Date the order was shipped
    sls_due_dt    INT,                      -- Date the order payment/delivery was due
    sls_sales     INT,                     -- Total sales amount for the line item
    sls_quantity  INT,                       -- Quantity of units sold
    sls_price     INT                      -- Unit price of the product sold
);
GO

-- ==============================================================================
-- Table: bronze.erp_CUST_AZ12
-- Purpose: Stores raw customer supplementary data from the ERP system
--          (birthdate and gender), matched to CRM customers via CID
-- ==============================================================================
DROP TABLE IF EXISTS bronze.erp_CUST_AZ12;
CREATE TABLE bronze.erp_CUST_AZ12
(
    CID   NVARCHAR(50)  ,  -- Customer ID from ERP, used to join back to CRM customer key
    BDATE DATE,                      -- Customer birthdate
    GEN   NVARCHAR(50)               -- Gender (raw, unstandardized value from ERP)
);
GO

-- ==============================================================================
-- Table: bronze.erp_LOC_A101
-- Purpose: Stores raw customer location/country data from the ERP system
-- ==============================================================================
DROP TABLE IF EXISTS bronze.erp_LOC_A101;
CREATE TABLE bronze.erp_LOC_A101
(
    CID   NVARCHAR(50)  ,  -- Customer ID from ERP, used to join back to CRM customer key
    CNTRY NVARCHAR(50)               -- Customer's country of residence
);
GO

-- ==============================================================================
-- Table: bronze.erp_PX_CAT_G1V2
-- Purpose: Stores raw product category and maintenance info from the ERP system
-- ==============================================================================
DROP TABLE IF EXISTS bronze.erp_PX_CAT_G1V2;
CREATE TABLE bronze.erp_PX_CAT_G1V2
(
    ID          NVARCHAR(20)  ,  -- Product category ID, links to bronze.crm_prd_info.prd_key (category segment)
    CAT         NVARCHAR(50),              -- Product category name
    MAINTENANCE NVARCHAR(50)               -- Maintenance flag/type for the product category
);
GO
