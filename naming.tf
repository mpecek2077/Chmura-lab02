# naming.tf -- konwencja nazw i tagów kursu, edycja 2026/27.
# Plik kopiowany BEZ ZMIAN do każdego repo labu.
#
# Logika zależna od workload (tags, names, wl) żyje w module tf-naming (Laboratorium 2,
# lab002-naming-module), opublikowanym jako artefakt OCI -- jedno źródło prawdy zamiast
# kopii w każdym repo. Wyjątek: rg i common (grupy zasobów i zasoby wspólne z lab 2) są
# liczone TUTAJ, lokalnie -- backend.tf potrzebuje ich przed `tofu init`, a OpenTofu "early
# evaluation" bloku backend dopuszcza tylko var.*/local.*, nie module.* (patrz backend.tf).
#
# Wartości labu ustawiamy w locals.tf:
#   locals {
#     lab            = "005"    # numer labu, trzy cyfry
#     workload       = "events" # obciążenie w kebab-case: małe litery, cyfry, pojedyncze '-'
#     workload_short = "evt"    # skrót (lub null) -- tylko gdy workload nie mieści się w limicie
#   }
#
# Konwencja (uproszczony CAF): <typ>-<obciążenie>-<YY>[-<student_id>], np. rg-labs-vm-26
#   * YY = dwie ostatnie cyfry roku edycji (26); pełny rok (2026) w tagu year i kluczu stanu
#   * student_id tylko w nazwach globalnie unikalnych (DNS): SA, KV, ACR, Function App
#   * styl zależny od znaków dozwolonych dla typu zasobu:
#       kebab-case  -- domyślnie: rg-, vnet-, kv-, func-, ...
#       snake_case  -- gdy '-' niedozwolony: galeria gal_labs_26
#       compact     -- tylko [a-z0-9]: Storage Account, ACR (stevents26<student_id>)
#   * student_id i YY są nietykalne; brak cichego obcinania -- gdy nazwa przekracza limit,
#     używany jest workload_short, a jeśli go brak lub też jest za długi: błąd planu (moduł)

variable "student_id" {
  description = <<-EOT
  Identyfikator studenta: g<grupa>k<podgrupa>n<6 ostatnich cyfr indeksu>,
  np. g14k01n123456. Zapewnia unikalność nazw globalnych (SA, KV, ACR, Function App).
  Najwygodniej ustawić raz w powłoce: export TF_VAR_student_id=g14k01n123456
  EOT
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^g[0-9]{1,2}k[0-9]{2}n[0-9]{6}$", var.student_id))
    error_message = "Format: g<grupa>k<podgrupa>n<6 ostatnich cyfr indeksu>, np. g14k01n123456."
  }
}

locals {
  year = "2026"
  yy   = substr(local.year, 2, 2) # "26" -- rok w nazwach zasobów
  sid  = var.student_id

  # Grupy zasobów (RG) -- wspólne dla kilku labów, tworzone w lab 2. Liczone lokalnie
  # (nie przez moduł): backend.tf odwołuje się do rg.common przed `tofu init`.
  rg = {
    common     = "rg-common-${local.yy}"
    basic      = "rg-labs-basic-${local.yy}"
    function   = "rg-labs-function-${local.yy}"
    vm         = "rg-labs-vm-${local.yy}"
    advanced   = "rg-labs-advanced-${local.yy}"
    industry40 = "rg-labs-industry40-${local.yy}"
  }

  # Zasoby wspólne (lab 2) -- do odczytu przez bloki data w kolejnych labach. Liczone
  # lokalnie: backend.tf odwołuje się do common.st_tfs przed `tofu init`.
  common = {
    kv      = "kv-main${local.yy}-${local.sid}"
    st_tfs  = "sttfstate${local.yy}${local.sid}"
    vnet    = "vnet-common-${local.yy}"
    cr      = "crcommon${local.yy}${local.sid}"
    id_pull = "id-acrpull-${local.yy}"
    gallery = "gal_labs_${local.yy}" # snake_case: galeria nie dopuszcza '-'
    log     = "log-common-${local.yy}"
  }
}

module "naming" {
  source = "oci://ghcr.io/pk-cloud-basics-2026-27/tf-naming?tag=v1.0.0"

  student_id     = var.student_id
  lab            = local.lab
  workload       = local.workload
  workload_short = local.workload_short
  year           = local.year
}

locals {
  course = module.naming.tags.course # zgodność wsteczna -- kilka labów odwołuje się wprost
  wl     = module.naming.wl
  tags   = module.naming.tags
  names  = module.naming.names
}

output "naming" {
  description = "Nazwy zasobów labu wg konwencji kursu"
  value       = local.names
}
