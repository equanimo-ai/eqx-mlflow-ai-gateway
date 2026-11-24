# Losing or rotating this value makes stored provider API keys undecryptable.
resource "random_password" "kek" {
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "kek" {
  name                    = "eqx-mlflow-gateway-${var.environment}-kek"
  recovery_window_in_days = var.environment == "dev" ? 0 : 30
}

resource "aws_secretsmanager_secret_version" "kek" {
  secret_id     = aws_secretsmanager_secret.kek.id
  secret_string = random_password.kek.result
}
