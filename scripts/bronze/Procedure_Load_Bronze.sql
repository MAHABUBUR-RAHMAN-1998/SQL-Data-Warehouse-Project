/*==============================================================================
    Title       : Bronze Layer - Full Load Procedure
    Procedure   : bronze.load_bronze
    Database    : DataWarehouse

    Purpose     : Loads raw CRM and ERP source data into the Bronze layer.
                  Existing Bronze table data is truncated before each full load.

    Warning     : This is a FULL LOAD process.
                  Running this procedure will DELETE all existing data from
                  the target Bronze tables before loading the source files.
                  Ensure the source CSV files are available at the specified
                  paths and that the SQL Server service account has permission
                  to access them.
==============================================================================*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze
AS
BEGIN
    -- CRM: Customer Information
    TRUNCATE TABLE bronze.crm_cust_info;

    BULK INSERT bronze.crm_cust_info
    FROM 'D:\Datasets\source_crm\cust_info.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- CRM: Product Information
    TRUNCATE TABLE bronze.crm_prd_info;

    BULK INSERT bronze.crm_prd_info
    FROM 'D:\Datasets\source_crm\prd_info.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- CRM: Sales Details
    TRUNCATE TABLE bronze.crm_sales_details;

    BULK INSERT bronze.crm_sales_details
    FROM 'D:\Datasets\source_crm\sales_details.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- ERP: Customer Information
    TRUNCATE TABLE bronze.erp_CUST_AZ12;

    BULK INSERT bronze.erp_CUST_AZ12
    FROM 'D:\Datasets\source_erp\CUST_AZ12.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- ERP: Location Information
    TRUNCATE TABLE bronze.erp_LOC_A101;

    BULK INSERT bronze.erp_LOC_A101
    FROM 'D:\Datasets\source_erp\LOC_A101.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );

    -- ERP: Product Category Information
    TRUNCATE TABLE bronze.erp_PX_CAT_G1V2;

    BULK INSERT bronze.erp_PX_CAT_G1V2
    FROM 'D:\Datasets\source_erp\PX_CAT_G1V2.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        TABLOCK
    );
END;
GO
