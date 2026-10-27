# Key Vault - główny zasób do przechowywania sekretów
resource "azurerm_key_vault" "this" {
  name                        = local.common.kv # globalnie unikalna, maks. 24 znaki
  location                    = azurerm_resource_group.common["common"].location
  resource_group_name         = azurerm_resource_group.common["common"].name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  # Ochrona przed wyczyszczeniem (purge) — zapobiega całkowitemu usunięciu Key Vault.
  # Uwaga: włączenie purge_protection jest nieodwracalne na poziomie vault-a.
  purge_protection_enabled   = true
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  tags = local.project_tags

  # lifecycle { prevent_destroy = true }
}
