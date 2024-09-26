resource "aws_lambda_function" "ops_medic_lambda" {
  filename      = "${local.build_dir}/lambda.zip"
  function_name = "ops-medic-callback"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ops_medic_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.ops_medic_api.execution_arn}/*/*"
}
