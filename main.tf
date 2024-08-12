provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "ops_medic_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "ops_medic_lambda_policy"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_lambda_function" "ops_medic_lambda" {
  filename      = "lambda.zip"
  function_name = "ops-medic-callback"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  source_code_hash = filebase64sha256("lambda.zip")
}

output "lambda_function_arn" {
  value = aws_lambda_function.ops_medic_lambda.arn
}

resource "aws_api_gateway_rest_api" "ops_medic_api" {
  name        = "ops-medic-api"
  description = "API Gateway for ops-medic Lambda"
}

resource "aws_api_gateway_resource" "ops_medic_resource" {
  rest_api_id = aws_api_gateway_rest_api.ops_medic_api.id
  parent_id   = aws_api_gateway_rest_api.ops_medic_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.ops_medic_api.id
  resource_id   = aws_api_gateway_resource.ops_medic_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ops_medic_api.id
  resource_id             = aws_api_gateway_resource.ops_medic_resource.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ops_medic_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ops_medic_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ops_medic_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "ops_medic_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.ops_medic_api.id
  stage_name  = "prod"
}
