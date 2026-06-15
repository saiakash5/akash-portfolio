# ---------------------------------------------------------------------------
# Serverless content plane: DynamoDB + Cognito + 2 Lambdas + API Gateway.
# Always-on and independent of the lightswitched ECS services, so the public
# site's content (and your ability to edit it) never depends on ECS being up.
# ---------------------------------------------------------------------------

variable "admin_email" { default = "saiakash5@gmail.com" }

# ---------- Content table (single region; DR was dropped) ----------

resource "aws_dynamodb_table" "content" {
  name         = "${var.project}-content"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }
}

# ---------- Cognito (login for the /admin portal) ----------

resource "aws_cognito_user_pool" "admin" {
  name = "${var.project}-admin"

  admin_create_user_config {
    allow_admin_create_user_only = true # no public sign-up; you create users
  }

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }
}

resource "aws_cognito_user_pool_client" "admin" {
  name         = "${var.project}-admin-web"
  user_pool_id = aws_cognito_user_pool.admin.id

  # SPA public client: no secret, uses the Authorization Code + PKCE flow.
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]

  callback_urls = ["https://${var.domain_name}/admin", "http://localhost:5173/admin"]
  logout_urls   = ["https://${var.domain_name}/admin", "http://localhost:5173/admin"]
}

resource "aws_cognito_user_pool_domain" "admin" {
  domain       = "${var.project}-admin"
  user_pool_id = aws_cognito_user_pool.admin.id
}

# The single admin user (you). Cognito emails a temporary password on create.
resource "aws_cognito_user" "admin" {
  user_pool_id = aws_cognito_user_pool.admin.id
  username     = var.admin_email

  attributes = {
    email          = var.admin_email
    email_verified = "true"
  }
}

# ---------- Lambda packaging ----------

data "archive_file" "read_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../services/content-api/read"
  output_path = "${path.module}/.build/read.zip"
}

data "archive_file" "admin_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../services/content-api/admin"
  output_path = "${path.module}/.build/admin.zip"
}

data "archive_file" "contact_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../services/contact-fn"
  output_path = "${path.module}/.build/contact.zip"
}

# ---------- Lambda IAM ----------

resource "aws_iam_role" "lambda" {
  name = "${var.project}-content-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ddb" {
  name = "content-ddb"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
        "dynamodb:DeleteItem", "dynamodb:Scan", "dynamodb:Query"
      ]
      Resource = aws_dynamodb_table.content.arn
    }]
  })
}

# ---------- Lambda functions ----------

resource "aws_lambda_function" "read" {
  function_name    = "${var.project}-content-read"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.read_lambda.output_path
  source_code_hash = data.archive_file.read_lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = { CONTENT_TABLE = aws_dynamodb_table.content.name }
  }
}

resource "aws_lambda_function" "admin" {
  function_name    = "${var.project}-content-admin"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.admin_lambda.output_path
  source_code_hash = data.archive_file.admin_lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = { CONTENT_TABLE = aws_dynamodb_table.content.name }
  }
}

# ---------- Contact Lambda (replaces FastAPI/ECS) ----------

resource "aws_iam_role" "contact_lambda" {
  name = "${var.project}-contact-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "contact_logs" {
  role       = aws_iam_role.contact_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "contact_perms" {
  name = "contact-write"
  role = aws_iam_role.contact_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.messages.arn
      },
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.contact.arn
      }
    ]
  })
}

resource "aws_lambda_function" "contact" {
  function_name    = "${var.project}-contact"
  role             = aws_iam_role.contact_lambda.arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.contact_lambda.output_path
  source_code_hash = data.archive_file.contact_lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      MESSAGES_TABLE = aws_dynamodb_table.messages.name
      TOPIC_ARN      = aws_sns_topic.contact.arn
    }
  }
}

# ---------- API Gateway HTTP API ----------

resource "aws_apigatewayv2_api" "content" {
  name          = "${var.project}-content"
  protocol_type = "HTTP"
}

# JWT authorizer: validates Cognito access tokens for admin routes.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.content.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.admin.id]
    issuer   = "https://cognito-idp.${var.primary_region}.amazonaws.com/${aws_cognito_user_pool.admin.id}"
  }
}

resource "aws_apigatewayv2_integration" "read" {
  api_id                 = aws_apigatewayv2_api.content.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.read.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "admin" {
  api_id                 = aws_apigatewayv2_api.content.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.admin.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "contact" {
  api_id                 = aws_apigatewayv2_api.content.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact.invoke_arn
  payload_format_version = "2.0"
}

# Public read route (no auth).
resource "aws_apigatewayv2_route" "read" {
  api_id    = aws_apigatewayv2_api.content.id
  route_key = "GET /api/content"
  target    = "integrations/${aws_apigatewayv2_integration.read.id}"
}

# Public contact route (no auth; WAF rate-limits at CloudFront).
resource "aws_apigatewayv2_route" "contact" {
  api_id    = aws_apigatewayv2_api.content.id
  route_key = "POST /api/contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact.id}"
}

# Admin routes (Cognito-protected). ANY + greedy proxy → the handler routes.
resource "aws_apigatewayv2_route" "admin" {
  api_id             = aws_apigatewayv2_api.content.id
  route_key          = "ANY /api/admin/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.admin.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.content.id
  name        = "$default"
  auto_deploy = true

  # Free aggregate throttling — a ceiling on total req/s to cap cost and
  # protect the Lambdas from a runaway loop or scraper. NOTE: this is
  # account/stage-wide, not per-IP (that needs WAF). Burst = token-bucket
  # capacity; rate = steady-state req/s.
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }

  # Tighter limit on the one write endpoint that emails me — real contact
  # submissions are rare, so this blunts spam bursts.
  route_settings {
    route_key              = "POST /api/contact"
    throttling_burst_limit = 5
    throttling_rate_limit  = 2
  }
}

resource "aws_lambda_permission" "read" {
  statement_id  = "AllowApiGwRead"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.read.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.content.execution_arn}/*/*"
}

resource "aws_lambda_permission" "admin" {
  statement_id  = "AllowApiGwAdmin"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.admin.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.content.execution_arn}/*/*"
}

resource "aws_lambda_permission" "contact" {
  statement_id  = "AllowApiGwContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.content.execution_arn}/*/*"
}

# ---------- Outputs (the frontend needs these for Cognito login) ----------

output "content_table" { value = aws_dynamodb_table.content.name }
output "api_gateway_domain" { value = replace(aws_apigatewayv2_api.content.api_endpoint, "https://", "") }
output "cognito_user_pool_id" { value = aws_cognito_user_pool.admin.id }
output "cognito_client_id" { value = aws_cognito_user_pool_client.admin.id }
output "cognito_domain" { value = "${aws_cognito_user_pool_domain.admin.domain}.auth.${var.primary_region}.amazoncognito.com" }
