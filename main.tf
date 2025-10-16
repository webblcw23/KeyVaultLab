# A Lab to demonstrate secure secret retrieval from Azure Key Vault using Managed Identity and Private Endpoint, accessed by an Azure Web App


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
# VNET + SUBNET (for Private Endpoint)
# --------------------------------------------------------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "kvlab-vnet-lewis"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name  
}

resource "azurerm_subnet" "subnet" {
  name                = "kvlab-subnet-keyvault"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name= azurerm_virtual_network.vnet.name
  address_prefixes    = ["10.0.1.0/24"]
}

# Private DNS Zone
resource "azurerm_private_dns_zone" "privatedns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Private DNS Zone to the VNet
resource "azurerm_private_dns_zone_virtual_network_link" "dnslink" {
  name                  = "kvlab-dnslink-lewis"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.privatedns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}

# Private Endpoint
resource "azurerm_private_endpoint" "kv_private_endpoint" {
  name                = "kv-private-endpoint-lewis"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id 

  private_service_connection {
    name                           = "kv-privateserviceconnection-lewis"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# DNS A Record for the Private Endpoint
resource "azurerm_private_dns_a_record" "kv_dns_record" {
  name                = azurerm_key_vault.kv.name
  zone_name           = azurerm_private_dns_zone.privatedns.name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  records            = [azurerm_private_endpoint.kv_private_endpoint.private_service_connection[0].private_ip_address]
}

# --------------------------------------------------------------------------------
# ROLE ASSIGNMENTS
# --------------------------------------------------------------------------------

# 1. ADMIN ROLE: Grants the identity running 'terraform apply' the permission 
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  
  # CRITICAL: My user's Object ID
  principal_id         = "1e5897ed-1475-42bc-b7cb-ed58ab3f5b6d" 

}

# 2. APPLICATION ROLE: Grants the Web App's Managed Identity permission to READ the secret
resource "azurerm_role_assignment" "app_to_kv_secrets_user" {
  scope                = azurerm_key_vault.kv.id
  
  # FIX: Updated principal_id reference to the new resource type
  principal_id         = azurerm_app_service.webapp.identity[0].principal_id 
  
  role_definition_name = "Key Vault Secrets User"
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

  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}


# --------------------------------------------------------------------------------
# WEB APP 
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

