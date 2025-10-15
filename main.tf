# A Lab to demonstrate use of Key Vault to store secrets for VMs in a secure manner

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  # NOTE: Replace with your actual Subscription ID
  subscription_id = var.subscription_id
}

# --------------------------------------------------------------------------------
# RESOURCE GROUP
# --------------------------------------------------------------------------------

# Create a Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "KeyVaultLab-RG"
  location = "uksouth"
}

# --------------------------------------------------------------------------------
# KEY VAULT + SECRET
# --------------------------------------------------------------------------------

# Create a key vault (using hardcoded name for this lab)
resource "azurerm_key_vault" "kv" {
  name                        = "kv-lewis"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  # NOTE: Replace with your actual Tenant ID
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  # CRITICAL: Explicitly enable RBAC to avoid permission issues
  enable_rbac_authorization   = true 
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7
}

# Add a secret to the Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "DbConnectionString"
  value        = "Server=tcp:myserver.database.windows.net,1433;Initial Catalog=myDataBase;Persist Security Info=False;User ID=mylogin;Password=myPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id
}


# --------------------------------------------------------------------------------
# WEB APP (FIXED TO USE AZURERM_APP_SERVICE FOR STABILITY)
# --------------------------------------------------------------------------------

# Web app service plan
resource "azurerm_service_plan" "plan" {
  name                = "webappserviceplan-lewis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "B1"
  os_type             = "Linux"
}

# Web app - switched to azurerm_app_service for explicit runtime control
resource "azurerm_app_service" "webapp" {
  name                = "webapp-lewis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    linux_fx_version = "DOTNET|8.0" 
  }

  app_settings = {
    "DbConnectionString" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db_connection_string.id})"
  }
}

# --------------------------------------------------------------------------------
# ROLE ASSIGNMENTS
# --------------------------------------------------------------------------------

# 1. ADMIN ROLE: Grants the identity running 'terraform apply' the permission 
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  
  # CRITICAL: Your actual user's Object ID
  principal_id         = "1e5897ed-1475-42bc-b7cb-ed58ab3f5b6d" 
}

# 2. APPLICATION ROLE: Grants the Web App's Managed Identity permission to READ the secret
resource "azurerm_role_assignment" "app_to_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  
  # FIX: Updated principal_id reference to the new resource type
  principal_id         = azurerm_app_service.webapp.identity[0].principal_id 
  
  role_definition_name = "Key Vault Secrets User"
}