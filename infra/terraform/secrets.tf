# Losing or rotating this value makes stored provider API keys undecryptable.
# prevent_destroy blocks any destroy or replace; a deliberate dev reset requires
# removing prevent_destroy from both resources first.
resource "random_password" "kek" {
  length  = 48
  special = false

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret" "kek" {
  name = "eqx-mlflow-gateway-${var.environment}-kek"

  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "kek" {
  secret_id     = aws_secretsmanager_secret.kek.id
  secret_string = random_password.kek.result
}
