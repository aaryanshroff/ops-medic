resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = local.lambda_layer_zip_path
  layer_name = "ops-medic-lambda-layer"

  compatible_runtimes = ["python3.11"]

  depends_on = [null_resource.build_lambda_layer]
}

resource "null_resource" "build_lambda_layer" {
  # triggers = {
  #   poetry_lock    = filemd5("${path.module}/../poetry.lock")
  #   pyproject_toml = filemd5("${path.module}/../pyproject.toml")
  # }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ${local.build_dir}/python
      poetry export -f requirements.txt | poetry run pip install -r /dev/stdin -t ${local.build_dir}/python
      cd ${local.build_dir} && zip -r ${local.lambda_layer_zip_path} python
    EOT
  }
}
