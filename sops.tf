# Klucz szyfrujący dla SOPS (wyłączony na koncie edukacyjnym z powodu getRotationPolicy)
resource "azurerm_key_vault_key" "sops_encryption_key" {
  count        = var.create_sops_key ? 1 : 0
  name         = "sops-encryption-key"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["decrypt", "encrypt", "sign", "verify", "wrapKey", "unwrapKey", "encrypt"]

  tags = merge(local.project_tags, { persistent = "true" })

  lifecycle { prevent_destroy = true }

  depends_on = [
    azurerm_role_assignment.key_vault_crypto_officer,
    azurerm_role_assignment.sops_crypto_user
  ]
}


# Data source do odczytu zaszyfrowanych sekretów z SOPS
# Uwaga: Plik secrets.yaml musi istnieć, nawet jeśli jest pusty
# sops.tf - data source do odczytu zaszyfrowanych sekretów
data "sops_file" "secrets" {
  source_file = "secrets.yaml"

  depends_on = [
    azurerm_key_vault_key.sops_encryption_key,
    azurerm_role_assignment.sops_crypto_user,
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}

# Mapowanie nazw sekretów z SOPS na nazwy w Key Vault
# sops.tf - mapowanie nazw sekretów z SOPS na nazwy w Key Vault
locals {
  # Statyczne mapowanie - klucze znane podczas planowania
  sops_to_keyvault_mapping = {
    # Odkomentuj gdy masz zaszyfrowany plik secrets.yaml:
    "devops-sp-username" = try(data.sops_file.secrets.data["devops_sp_username"], "")
    "devops-sp-password" = try(data.sops_file.secrets.data["devops_sp_password"], "")
  }
}

# Sekrety DevOps z SOPS jako źródło
# Sekrety DevOps z SOPS jako źródło
resource "azurerm_key_vault_secret" "devops" {
  # Użyj mapy w całości — klucze znane podczas planu; puste wartości utworzą puste sekrety.
  # filtr jest problematyczny z powodu ograniczeń w terraform/tofu
  for_each = local.sops_to_keyvault_mapping

  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.this.id

  tags = merge(local.project_tags, {
    source    = "sops"
    encrypted = "true"
  })

  lifecycle { prevent_destroy = true }

  depends_on = [
    azurerm_key_vault_key.sops_encryption_key,
    azurerm_role_assignment.sops_crypto_user,
    azurerm_role_assignment.key_vault_secrets_officer
  ]
}
