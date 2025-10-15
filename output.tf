output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "web_app_hostname" {
  value = azurerm_app_service.webapp.default_site_hostname
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "managed_identity_principal_id" {
  value = azurerm_app_service.webapp.identity[0].principal_id
}