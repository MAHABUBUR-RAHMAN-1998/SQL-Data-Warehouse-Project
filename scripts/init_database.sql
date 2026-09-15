/*
===============================================================================
Script Name:    Initialize DataWarehouse Database
Script Purpose: Creates the 'DataWarehouse' database from scratch, then creates
              the three schemas used to organize the data warehouse layers:
                  - bronze : raw, unprocessed source data
                  - silver : cleaned and standardized data
                  - gold   : business-ready, aggregated data
===============================================================================
WARNING:
    Running this script will DROP the existing 'DataWarehouse' database if
    it already exists. ALL data in that database will be PERMANENTLY LOST.
    Make sure you have a verified backup before running this script, and
    confirm you are connected to the correct SQL Server instance.
===============================================================================
*/

-- Switch context to the 'master' database so we can safely drop/create databases
USE master;
GO

-- Drop the DataWarehouse database if it already exists, to allow a clean rebuild
DROP DATABASE IF EXISTS DataWarehouse;
GO

-- Create a fresh DataWarehouse database
CREATE DATABASE DataWarehouse;
GO

-- Switch context into the newly created DataWarehouse database
USE DataWarehouse;
GO

-- Create the 'bronze' schema: holds raw, unprocessed data as ingested from source systems
CREATE SCHEMA bronze;
GO

-- Create the 'silver' schema: holds cleaned, transformed, and standardized data
CREATE SCHEMA silver;
GO

-- Create the 'gold' schema: holds curated, business-ready data for reporting/analytics
CREATE SCHEMA gold;
GO