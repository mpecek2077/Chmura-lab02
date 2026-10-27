# Grupy zasobów (RG) -- nazwy z naming.tf (local.rg), klucze mapy jak w local.rg
resource "azurerm_resource_group" "common" {
  for_each = { for k, v in var.common_resource_groups : k => v if v.enabled }

  name     = local.rg[each.key]
  location = var.location
  tags = merge(local.project_tags, {
    labs = each.value.labs
  })
  lifecycle {
    prevent_destroy = true
  }
}