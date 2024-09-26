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

resource "aws_api_gateway_deployment" "ops_medic_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.ops_medic_api.id
  stage_name  = "prod"
}
