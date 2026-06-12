# Contact-form notifications + cost guardrail.

variable "alert_email" { default = "saiakash5@gmail.com" }

# ---------- SNS: email me every contact-form submission ----------

resource "aws_sns_topic" "contact" {
  name = "${var.project}-contact-notifications"
}

# NOTE: AWS sends a confirmation email on first apply — click "Confirm
# subscription" in it or no notifications are delivered.
resource "aws_sns_topic_subscription" "contact_email" {
  topic_arn = aws_sns_topic.contact.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ---------- AWS Budget: alert before costs surprise anyone ----------

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project}-monthly"
  budget_type  = "COST"
  limit_amount = "80"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # percent of the $80 limit
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
