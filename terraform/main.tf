terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-rmw"
  location = var.location
}

# Storage Account
resource "azurerm_storage_account" "st" {
  name                     = "strmw${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# SQL Server
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-rmw"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin
  administrator_login_password = var.sql_password
}

# SQL Database
resource "azurerm_mssql_database" "db" {
  name      = "db-rmw"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# Data Factory
resource "azurerm_data_factory" "adf" {
  name                = "adf-rmw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# Blob Linked Service
resource "azurerm_data_factory_linked_service_azure_blob_storage" "blob_ls" {
  name            = "ls_blob_rmw"
  data_factory_id = azurerm_data_factory.adf.id
  connection_string = azurerm_storage_account.st.primary_connection_string
}

# SQL Linked Service
resource "azurerm_data_factory_linked_service_sql_server" "sql_ls" {
  name            = "ls_sql_rmw"
  data_factory_id = azurerm_data_factory.adf.id
  connection_string = "Server=tcp:sql-rmw.database.windows.net,1433;Initial Catalog=db-rmw;User ID=${var.sql_admin};Password=${var.sql_password};"
}

# Function App용 Storage Account
resource "azurerm_storage_account" "func_st" {
  name                     = "stfuncrmw${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App Service Plan (Consumption)
resource "azurerm_service_plan" "func_plan" {
  name                = "plan-rmw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# Function App
resource "azurerm_linux_function_app" "func" {
  name                       = "func-rmw"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = var.location
  storage_account_name       = azurerm_storage_account.func_st.name
  storage_account_access_key = azurerm_storage_account.func_st.primary_access_key
  service_plan_id            = azurerm_service_plan.func_plan.id

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  app_settings = {
    "STORAGE_CONNECTION_STRING" = azurerm_storage_account.st.primary_connection_string
  }
}

# Logic Apps
resource "azurerm_logic_app_workflow" "la" {
  name                = "la-rmw"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}
