locals {
  budgets_for_alerts = toset(["10", "20", "50"])
}

resource "azurerm_consumption_budget_subscription" "this" {
  for_each = local.budgets_for_alerts
  name     = "Budget-for-${each.key}-usd-subscription-consumption"

  subscription_id = data.azurerm_subscription.current.id
  amount          = each.key
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z" # rok akademicki 2026/27
    end_date   = "2027-10-01T00:00:00Z"
  }

  notification {
    enabled   = true
    threshold = 70.0 # %
    operator  = "EqualTo"

    contact_emails = var.contact_emails
  }

  notification {
    enabled   = true
    threshold = 90.0 # %
    operator  = "EqualTo"

    contact_emails = var.contact_emails
  }

  notification {
    enabled        = true
    threshold      = 100.0
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = var.contact_emails
  }
}
