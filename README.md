# lab002-common-resources -- zasoby wspólne 2026/27

Projekt zawiera wspólne zasoby Azure dla laboratoriów kursu podstaw rozwiązań chmurowych.

## Zasoby

Po Laboratorium 2:

- **Resource Groups** - grupy zasobów dla różnych bloków tematycznych
- **Budget Alerts** - alerty budżetowe dla kontroli kosztów (adresy z `TF_VAR_contact_emails`)
- **Azure Key Vault** - bezpieczne przechowywanie sekretów
- **SOPS Integration** - szyfrowanie sekretów w kodzie
- **Storage Account** `sttfstate26<student_id>` - zdalny stan OpenTofu wszystkich labów

Kolejne zasoby wspólne dokładamy do tego repo w labach, w których są pierwszy raz potrzebne
(kod w `examples/` danego labu, katalogi `labNNN-common-*`): Log Analytics (lab 5), sieć
(lab 6), galeria obrazów (lab 7), Bastion i obraz jump hosta (lab 8), ACR (lab 9).

Nazwy i tagi pochodzą z `naming.tf` (kopia z `src/lab/_template/`). Przed `tofu init`:

```bash
export TF_VAR_student_id=g14k01n123456
export TF_VAR_contact_emails='["imie.nazwisko@student.pk.edu.pl","drugi.adres@example.com"]'
```

## Użycie SOPS (Secrets OPerationS)

### Wymagania

1. **Zainstaluj SOPS:**

   ```bash
   # macOS
   brew install sops

   # Ubuntu/Debian
   sudo apt install sops

   # Windows (Chocolatey)
   choco install sops
   ```

2. **Zaloguj się do Azure:**

   ```bash
   az login
   ```

### Workflow z SOPS

#### 1. Przygotowanie środowiska

```bash
# Sklonuj projekt
git clone <repository-url>
cd lab002-common-resources

# Inicjalizuj OpenTofu
tofu init
```

#### 2. Wdróż Key Vault z kluczem szyfrującym

```bash
# Wdróż tylko Key Vault i klucz szyfrujący
tofu apply -target=azurerm_key_vault.this
tofu apply -target=azurerm_key_vault_key.sops_encryption_key
```

#### 3. Przygotuj sekrety

```bash
# Edytuj plik z sekretami (niezaszyfrowany)
nano secrets.yaml
```

Przykładowa zawartość `secrets.yaml`:

```yaml
devops_sp_username: "12345678-1234-1234-1234-123456789012"
devops_sp_password: "abcdef12-3456-7890-abcd-ef1234567890"
devops_sp_tenant: "87654321-4321-4321-4321-210987654321"
database_connection_string: "Server=tcp:example.database.windows.net,1433;Database=mydb;"
api_key: "sk-1234567890abcdef1234567890abcdef"
```

#### 4. Zaszyfruj sekrety

```bash
# Zaszyfruj plik sekretów
sops -e secrets.yaml > secrets.encrypted.yaml

# Zastąp oryginalny plik zaszyfrowaną wersją
mv secrets.encrypted.yaml secrets.yaml

# Sprawdź czy plik jest zaszyfrowany
head secrets.yaml
```

#### 5. Wdróż wszystkie zasoby

```bash
# Wdróż wszystkie zasoby włącznie z sekretami
tofu apply
```

### Zarządzanie sekretami

#### Edycja zaszyfrowanych sekretów

```bash
# SOPS automatycznie odszyfruje plik do edycji
sops secrets.yaml

# Po zapisaniu plik zostanie automatycznie zaszyfrowany
```

#### Dodanie nowego sekretu

```bash
# Edytuj zaszyfrowany plik
sops secrets.yaml

# Dodaj nową linię:
# new_secret_name: "nowa-wartość-sekretu"

# Zapisz i zamknij edytor

# Zaktualizuj mapowanie w kv.tf jeśli potrzebne
# Wdróż zmiany
tofu apply
```

#### Wyświetlenie zaszyfrowanego pliku

```bash
# Wyświetl zawartość bez deszyfrowania
cat secrets.yaml

# Wyświetl odszyfrowaną zawartość
sops -d secrets.yaml
```

### Weryfikacja

#### Sprawdź sekrety w Key Vault

```bash
# Lista wszystkich sekretów
az keyvault secret list --vault-name kv-main26-g14k01n123456 --output table

# Odczyt konkretnego sekretu
az keyvault secret show --vault-name kv-main26-g14k01n123456 --name devops-sp-username --query "value" -o tsv
```

#### Sprawdź klucz szyfrujący

```bash
# Sprawdź czy klucz istnieje
az keyvault key show --vault-name kv-main26-g14k01n123456 --name sops-encryption-key
```

### Bezpieczeństwo

#### Dobre praktyki

- Zaszyfrowany plik `secrets.yaml` można bezpiecznie commitować
- Klucz szyfrujący jest przechowywany w Azure Key Vault
- Dostęp kontrolowany przez Azure RBAC
- Automatyczne szyfrowanie po edycji

#### Czego unikać

- Nigdy nie commituj niezaszyfrowanego pliku z sekretami
- Nie udostępniaj kluczy szyfrujących
- Nie używaj sekretów w logach lub output

### Troubleshooting

#### Problem: "failed to decrypt sops file"

```bash
# Sprawdź logowanie do Azure
az account show

# Sprawdź uprawnienia do Key Vault
az keyvault key show --vault-name kv-main26-g14k01n123456 --name sops-encryption-key

# Sprawdź konfigurację SOPS
cat .sops.yaml
```

#### Problem: "key not found"

```bash
# Upewnij się że klucz istnieje
tofu apply -target=azurerm_key_vault_key.sops_encryption_key

# Sprawdź URL klucza w .sops.yaml
```

#### Problem: "access denied"

Vault działa w trybie Azure RBAC (`rbac_authorization_enabled = true`), więc access policies
(`az keyvault set-policy`) są ignorowane -- uprawnienia nadaje się rolami.

```bash
KV_ID=$(az keyvault show --name kv-main26-g14k01n123456 --query id -o tsv)
ME=$(az ad signed-in-user show --query id -o tsv)

# Sprawdź role przypisane do Ciebie na poziomie vaulta
az role assignment list --scope "$KV_ID" --assignee "$ME" --query "[].roleDefinitionName" -o tsv

# Dodaj brakującą rolę (SOPS: szyfrowanie/deszyfrowanie kluczem)
az role assignment create --role "Key Vault Crypto User" --assignee "$ME" --scope "$KV_ID"
```

Najlepiej jednak nadawać role w kodzie (`rbac.tf`) i wykonać `tofu apply`. Propagacja nowej
roli trwa zwykle kilka minut.

#### Problem: "getrotationpolicy permission"

```bash
# Sprawdź czy masz uprawnienia do rotation policy
az keyvault key show --vault-name kv-main26-g14k01n123456 --name sops-encryption-key

# Jeśli brak uprawnień, kod automatycznie ignoruje rotation_policy
# (już skonfigurowane w kv.tf przez lifecycle.ignore_changes)
```

## Struktura projektu

```text
lab002-common-resources/
├── .sops.yaml              # Konfiguracja SOPS
├── secrets.yaml            # Zaszyfrowane sekrety (bezpieczne do commit)
├── naming.tf               # Konwencja nazw i tagów (wspólna dla labów)
├── main.tf                 # Resource Groups
├── budget.tf               # Alerty budżetowe
├── kv.tf, sops.tf, rbac.tf # Key Vault, SOPS, uprawnienia
├── storage_account.tf      # Storage Account na stan labów (krok: Laboratorium 2)
├── backend.tf              # zdalny backend (z szablonu; dodawany w Laboratorium 2)
├── variables.tf            # Zmienne projektu
├── versions.tf             # Providers (azurerm + sops)
├── locals.tf               # Wartości labu i lokalne zmienne
└── README.md               # Kompletna dokumentacja
```

## Deployment

```bash
# Pełny workflow
tofu init
tofu plan
tofu apply

# Tylko Key Vault
tofu apply -target=azurerm_key_vault.this

# Tylko sekrety
tofu apply -target=azurerm_key_vault_secret.devops
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.12 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 5.8 |
| <a name="requirement_sops"></a> [sops](#requirement\_sops) | ~> 1.3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 5.8 |
| <a name="provider_sops"></a> [sops](#provider\_sops) | ~> 1.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_bastion_host.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/bastion_host) | resource |
| [azurerm_consumption_budget_subscription.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/consumption_budget_subscription) | resource |
| [azurerm_container_registry.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_key.sops_encryption_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_key) | resource |
| [azurerm_key_vault_secret.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_log_analytics_workspace.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_public_ip.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_resource_group.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_crypto_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.key_vault_secrets_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.sops_crypto_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.storage_blob_data_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.storage_blob_data_contributor_sp](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_shared_image.labs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/shared_image) | resource |
| [azurerm_shared_image_gallery.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/shared_image_gallery) | resource |
| [azurerm_storage_account.backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_management_policy.backend](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_management_policy) | resource |
| [azurerm_subnet.bastion](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.labs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_user_assigned_identity.acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_virtual_network.common](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault_key.sops_encryption_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_key) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [sops_file.secrets](https://registry.terraform.io/providers/carlpett/sops/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acr_admin_enabled"></a> [acr\_admin\_enabled](#input\_acr\_admin\_enabled) | Konto administratora ACR (login/hasło). Domyślnie wyłączone -- push przez `az acr login`,<br/>pull przez tożsamość z rolą AcrPull. Włącz tylko dla workflow GitHub Actions z lab 9,<br/>który loguje się do rejestru loginem i hasłem (konto studenckie nie pozwala utworzyć<br/>Service Principal). | `bool` | `false` | no |
| <a name="input_acr_enabled"></a> [acr\_enabled](#input\_acr\_enabled) | Czy utworzyć Azure Container Registry (SKU Basic, stały koszt dzienny).<br/>Włącz przed lab 9, wyłącz po jego zakończeniu. | `bool` | `false` | no |
| <a name="input_bastion_enabled"></a> [bastion\_enabled](#input\_bastion\_enabled) | Czy utworzyć Azure Bastion (płatny godzinowo -- włączaj tylko na czas zajęć) | `bool` | `false` | no |
| <a name="input_bastion_sku"></a> [bastion\_sku](#input\_bastion\_sku) | SKU dla Azure Bastion (Basic lub Standard) | `string` | `"Basic"` | no |
| <a name="input_bastion_subnet_prefix"></a> [bastion\_subnet\_prefix](#input\_bastion\_subnet\_prefix) | Prefiks podsieci AzureBastionSubnet (min. /26) | `string` | `"10.0.0.0/26"` | no |
| <a name="input_common_resource_groups"></a> [common\_resource\_groups](#input\_common\_resource\_groups) | Grupy zasobów (RG). Klucz mapy wybiera nazwę z local.rg (naming.tf),<br/>`labs` -- numery labów korzystających z grupy (trafia do tagu). | <pre>map(object({<br/>    enabled = bool<br/>    labs    = string<br/>  }))</pre> | <pre>{<br/>  "advanced": {<br/>    "enabled": true,<br/>    "labs": "10"<br/>  },<br/>  "basic": {<br/>    "enabled": true,<br/>    "labs": "1-4"<br/>  },<br/>  "common": {<br/>    "enabled": true,<br/>    "labs": "2-11"<br/>  },<br/>  "function": {<br/>    "enabled": true,<br/>    "labs": "5-6"<br/>  },<br/>  "industry40": {<br/>    "enabled": true,<br/>    "labs": "11"<br/>  },<br/>  "vm": {<br/>    "enabled": true,<br/>    "labs": "7-9"<br/>  }<br/>}</pre> | no |
| <a name="input_create_sops_key"></a> [create\_sops\_key](#input\_create\_sops\_key) | Jeśli `true`, provider utworzy klucz `Key Vault` 'sops-encryption-key` używany przez SOPS.<br/>Ustaw `false`jeśli chcesz ustawić klucz manualnie z uwagi na przykład na ograniczenie uprawnień.<br/>` | `bool` | `false` | no |
| <a name="input_default_outbound_access_enabled"></a> [default\_outbound\_access\_enabled](#input\_default\_outbound\_access\_enabled) | Domyślny dostęp wychodzący do internetu z podsieci (bez NAT Gateway).<br/>Domyślnie wyłączony -- podsieci prywatne; NAT Gateway jest ćwiczeniem opcjonalnym lab 7. | `bool` | `false` | no |
| <a name="input_enable_access_key"></a> [enable\_access\_key](#input\_enable\_access\_key) | Czy włączyć generowanie kluczy dostępu (przydatne dla backup/CI/CD). | `bool` | `true` | no |
| <a name="input_gallery_images"></a> [gallery\_images](#input\_gallery\_images) | Definicje obrazów w galerii: nazwa -> offer/sku/trusted\_launch (wersje budowane w lab 7 i 8).<br/>trusted\_launch = true dla obrazów VM z secure boot i vTPM (jump host w lab 8). | <pre>map(object({<br/>    offer          = string<br/>    sku            = string<br/>    trusted_launch = optional(bool, false)<br/>  }))</pre> | <pre>{<br/>  "img-lab007-base": {<br/>    "offer": "debian13",<br/>    "sku": "base"<br/>  },<br/>  "img-lab008-jumphost": {<br/>    "offer": "debian13",<br/>    "sku": "jumphost",<br/>    "trusted_launch": true<br/>  }<br/>}</pre> | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region - konto EDU ma ograniczoną listę regionów do:<br/>- germanywestcentral<br/>- switzerlandnorth<br/>- francecentral<br/>- swedencentral<br/>- norwayeast<br/>Niektórych zasobów np. `Key Vault` nie da się utworzyć poza tymi regionami | `string` | `"francecentral"` | no |
| <a name="input_log_daily_quota_gb"></a> [log\_daily\_quota\_gb](#input\_log\_daily\_quota\_gb) | Dzienny limit ingestii logów w GB -- chroni budżet subskrypcji | `number` | `0.2` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Retencja logów w dniach (30 -- bez dodatkowej opłaty za przechowywanie) | `number` | `30` | no |
| <a name="input_project"></a> [project](#input\_project) | Nazwa projektu = nazwa repo | `string` | `"lab002-common-resources"` | no |
| <a name="input_sops-encryption-key_name"></a> [sops-encryption-key\_name](#input\_sops-encryption-key\_name) | Nazwa klucza `Key Vault` używanego przez `SOPS` do szyfrowania sekretów. | `string` | `"sops-encryption-key"` | no |
| <a name="input_sops_principal_object_id"></a> [sops\_principal\_object\_id](#input\_sops\_principal\_object\_id) | (opcjonalne) Object ID tożsamości,<br/>która ma otrzymać uprawnienia kluczowe dla SOPS. | `string` | `""` | no |
| <a name="input_student_id"></a> [student\_id](#input\_student\_id) | Identyfikator studenta: g<grupa>k<podgrupa>n<6 ostatnich cyfr indeksu>,<br/>np. g14k01n123456. Zapewnia unikalność nazw globalnych (SA, KV, ACR, Function App).<br/>Najwygodniej ustawić raz w powłoce: export TF\_VAR\_student\_id=g14k01n123456 | `string` | n/a | yes |
| <a name="input_subnets_map"></a> [subnets\_map](#input\_subnets\_map) | Podsieci dla labów: klucz -> prefiks adresu (nazwa: snet-labs-<klucz>) | `map(string)` | <pre>{<br/>  "a": "10.0.1.0/24",<br/>  "b": "10.0.2.0/24",<br/>  "c": "10.0.3.0/24"<br/>}</pre> | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Przestrzeń adresowa wspólnej sieci wirtualnej | `list(string)` | <pre>[<br/>  "10.0.0.0/20"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_keys"></a> [access\_keys](#output\_access\_keys) | Access keys dla backup/CI/CD (jeśli włączone) |
| <a name="output_acr_login_server"></a> [acr\_login\_server](#output\_acr\_login\_server) | Adres rejestru ACR (null, gdy acr\_enabled = false) |
| <a name="output_acr_pull_identity_id"></a> [acr\_pull\_identity\_id](#output\_acr\_pull\_identity\_id) | Id tożsamości zarządzanej z rolą AcrPull |
| <a name="output_backend_config"></a> [backend\_config](#output\_backend\_config) | Backend configuration for OpenTofu |
| <a name="output_gallery"></a> [gallery](#output\_gallery) | Galeria obrazów i definicje obrazów |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Nazwa wspólnego Key Vault |
| <a name="output_log_analytics_workspace_id"></a> [log\_analytics\_workspace\_id](#output\_log\_analytics\_workspace\_id) | Id wspólnego Log Analytics workspace |
| <a name="output_resource_groups"></a> [resource\_groups](#output\_resource\_groups) | Nazwy utworzonych grup zasobów |
| <a name="output_sops_key_kid"></a> [sops\_key\_kid](#output\_sops\_key\_kid) | Key identifier (KID) for the SOPS Key Vault key. Use this in sops --azure-kv or .sops.yaml. |
| <a name="output_vnet"></a> [vnet](#output\_vnet) | Wspólna sieć: nazwa, id i podsieci (dla bloków data w labach 7-10) |
<!-- END_TF_DOCS -->
