# TODO: Dodaj data source subskrypcji (budżet, krok 2)

# TODO: Dodaj data source client_config (Key Vault/SOPS, krok 3)

# TODO: Dodaj data source klucza SOPS gdy create_sops_key=false (krok 3)
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}
