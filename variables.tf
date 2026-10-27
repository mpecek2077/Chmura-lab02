variable "project" {
  description = "Nazwa projektu = nazwa repo"
  type        = string
  nullable    = false
  default     = "lab002-common-resources"
}

variable "common_resource_groups" {
  description = <<-EOT
  Grupy zasobów (RG). Klucz mapy wybiera nazwę z local.rg (naming.tf),
  `labs` -- numery labów korzystających z grupy (trafia do tagu).
  EOT
  type = map(object({
    enabled = bool
    labs    = string
  }))
  nullable = false
  default = {

    common     = { enabled = true, labs = "2-11" } # zasoby wspólne, trwałe
    basic      = { enabled = true, labs = "1-4" }
    function   = { enabled = true, labs = "5-6" }
    vm         = { enabled = true, labs = "7-9" }
    advanced   = { enabled = true, labs = "10" }
    industry40 = { enabled = true, labs = "11" }
  }
  validation {
    condition     = try(var.common_resource_groups["common"].enabled, false)
    error_message = "Grupa `common` jest wymagana -- trafiają do niej zasoby wspólne."
  }
}

variable "location" {
  description = <<-EOT
  Azure region - konto EDU ma ograniczoną listę regionów do:
  - germanywestcentral
  - switzerlandnorth
  - francecentral
  - swedencentral
  - norwayeast
  Niektórych zasobów np. `Key Vault` nie da się utworzyć poza tymi regionami
  EOT
  nullable    = false
  type        = string
  default     = "swedencentral"
}

variable "sops-encryption-key_name" {
  description = "Nazwa klucza `Key Vault` używanego przez `SOPS` do szyfrowania sekretów."
  type        = string
  default     = "sops-encryption-key"
}

variable "create_sops_key" {
  description = <<-EOT
  Jeśli `true`, provider utworzy klucz `Key Vault` 'sops-encryption-key` używany przez SOPS.
  Ustaw `false` jeśli chcesz ustawić klucz manualnie z uwagi na przykład na ograniczenie uprawnień.
  EOT
  type        = bool
  nullable    = false
  default     = false
}

# Opcjonalne: objectId principal-a (np. użytkownika `devops` -- część opcjonalna labu), któremu
# chcesz nadać prawa do klucza. Jeśli puste, używany jest principal uruchamiający OpenTofu
# (data.azurerm_client_config.current.object_id).
variable "sops_principal_object_id" {
  description = <<-EOT
  (opcjonalne) Object ID tożsamości,
  która ma otrzymać uprawnienia kluczowe dla SOPS.
  EOT
  type        = string
  nullable    = false
  default     = ""
}

variable "contact_emails" {
  description = <<-EOT
  Adresy e-mail, na które trafią alerty budżetowe (jeden lub kilka). Najwygodniej ustawić
  raz w powłoce (Laboratorium 2), np.:
  export TF_VAR_contact_emails='["imie.nazwisko@student.pk.edu.pl","drugi.adres@example.com"]'
  EOT
  default     = ["imie.nazwisko@student.pk.edu.pl", "drugi.adres@example.com"]
  type        = list(string)
  nullable    = false
  validation {
    condition = length(var.contact_emails) > 0 && alltrue([
      for e in var.contact_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))
    ])
    error_message = "Podaj co najmniej jeden poprawny adres e-mail, np. imie.nazwisko@student.pk.edu.pl."
  }
}
