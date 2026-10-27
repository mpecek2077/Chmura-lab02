# RBAC - uprawnienia do tworzenia kluczy szyfrujących
resource "azurerm_role_assignment" "key_vault_crypto_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = local.principal_id # Konfigurowane w locals.tf
}

# RBAC - uprawnienia do zarządzania sekretami w Key Vault
resource "azurerm_role_assignment" "key_vault_secrets_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = local.principal_id # Konfigurowane w locals.tf
}

# RBAC - uprawnienia do szyfrowania/deszyfrowania dla SOPS
resource "azurerm_role_assignment" "sops_crypto_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = local.principal_id # Konfigurowane w locals.tf
}
