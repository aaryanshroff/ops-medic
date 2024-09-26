locals {
  build_dir             = "${path.module}/../build"
  lambda_layer_zip_path = "${local.build_dir}/lambda_layer.zip"
}
