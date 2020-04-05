resource "aws_lambda_function" "cloudsearch_proxy" {
  function_name = "CloudSearch_proxy"
  filename      = "${data.archive_file.lambda_cloudsearch_proxy_zip.output_path}"
  handler       = "index.handler"
  role          = "${aws_iam_role.cloud_search_lambda_role.arn}"
  runtime       = "nodejs8.10"
  publish       = "false"
  timeout       = "10"
  memory_size   = "256"
  depends_on    = ["data.archive_file.lambda_cloudsearch_proxy_zip"]
}

output "lambda_arn" {
  value = "${aws_lambda_function.cloudsearch_proxy.arn}"
}

data "template_file" "lambda_index_js" {
  template = "${file("../files/lambda/search/index_template.js")}"

  vars = {
    cs_search_endpoint = "${chomp(data.template_file.search_endpoint.rendered)}"
    site_host_map_key  = "${aws_s3_bucket_object.site_host_map.key}"
    bucket             = "${aws_s3_bucket.s3.bucket}"
  }
}

resource "local_file" "cloudsearch_proxy" {
  content  = "${data.template_file.lambda_index_js.rendered}"
  filename = "../files/lambda/search/index.js"
}

# zips the function for uploading to lambda
data "archive_file" "lambda_cloudsearch_proxy_zip" {
  type        = "zip"
  output_path = "../files/lambda_zip/lambda_cloudsearch_proxy.zip"

  source_dir = "../files/lambda/search"

  depends_on = ["local_file.cloudsearch_proxy"]
}

# create role for lambda
resource "aws_iam_role" "cloud_search_lambda_role" {
  assume_role_policy = <<EOF
{
      "Version":"2012-10-17",
      "Statement":[
        {
          "Effect":"Allow",
          "Principal":{
            "Service":"lambda.amazonaws.com"
          },
          "Action":"sts:AssumeRole"
        }
      ]
}
EOF

  description = "Allows Lambda functions to call s3, cloudwatch, and cloudsearch."
}

# attach AWS managed policy for cloudwatch logging to lambda role
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_access" {
  role       = "${aws_iam_role.cloud_search_lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# allow access to the lambda portion of the application bucket
resource "aws_iam_policy" "lambda_s3_access" {
  name        = "lambda_s3_read_access_policy"
  description = "Allow access to read the bucket /lambda/* contents"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${var.application_shared_bucket_name[terraform.workspace]}"]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::${var.application_shared_bucket_name[terraform.workspace]}/lambda/*"]
    }
  ]
}
EOF
}

# attach s3 access policy to role
resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = "${aws_iam_role.cloud_search_lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_s3_access.arn}"
}

# allow access to cloudsearch domains in the same account
resource "aws_iam_policy" "lambda_cloudsearch_access" {
  name        = "s3_cloudsearch_read_access_policy"
  description = "Allow access to cloudsearch"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudsearch:search",
                "cloudsearch:suggest"
            ],
            "Resource": "arn:aws:cloudsearch:eu-central-1:${data.aws_caller_identity.current.account_id}:domain/${data.terraform_remote_state.2.cloudsearch_domain}"
        }
    ]
}
EOF
}

# attach cloudsearch policy to role
resource "aws_iam_role_policy_attachment" "lambda_cloudsearch_access" {
  role       = "${aws_iam_role.cloud_search_lambda_role.name}"
  policy_arn = "${aws_iam_policy.lambda_cloudsearch_access.arn}"
}

resource "aws_lambda_permission" "lambda_suggest_permission" {
  statement_id  = "allow_api_gateway_suggest_invoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cloudsearch_proxy.function_name}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deployment_suggest.execution_arn}*"
}

resource "aws_lambda_permission" "lambda_search_permission" {
  statement_id  = "allow_api_gateway_invoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cloudsearch_proxy.function_name}"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_deployment.deployment_search.execution_arn}*"
}
