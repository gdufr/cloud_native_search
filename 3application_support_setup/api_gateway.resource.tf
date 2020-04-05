/* ==== BEGIN - API Gateway Creation ==== */
# Create rest api
resource "aws_api_gateway_rest_api" "cloud_search_api_gw" {
  name        = "cloud_search_apigw"
  description = "Search API Gateway"
  body        = "${data.template_file.api_gateway_swagger.rendered}"

  lifecycle {
    ignore_changes = ["body", "name", "description"]
  }
}

resource "aws_api_gateway_method_settings" "cloud_suggester_api_gw" {
  rest_api_id = "${aws_api_gateway_rest_api.cloud_search_api_gw.id}"
  stage_name  = "${aws_api_gateway_deployment.deployment_suggest.stage_name}"
  method_path = "*/*"

  settings {
    logging_level = "INFO"
  }

  depends_on = ["aws_api_gateway_account.apigw_to_cloudwatch"]
}

resource "aws_api_gateway_method_settings" "cloud_search_api_gw" {
  rest_api_id = "${aws_api_gateway_rest_api.cloud_search_api_gw.id}"
  stage_name  = "${aws_api_gateway_deployment.deployment_search.stage_name}"
  method_path = "*/*"

  settings {
    logging_level = "INFO"
  }

  depends_on = ["aws_api_gateway_account.apigw_to_cloudwatch"]
}

# Create role for lambda integration
resource "aws_iam_role" "apigw_to_lambda" {
  name = "api_gw_to_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# set the api gateway account  
resource "aws_api_gateway_account" "apigw_to_cloudwatch" {
  cloudwatch_role_arn = "${aws_iam_role.apigw_to_lambda.arn}"
}

# attach cloudwatch access policy to apigw role
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_access" {
  role       = "${aws_iam_role.apigw_to_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_policy" "apigw_lambda_access" {
  name        = "apigw_lambda_access_policy"
  description = "Allow access for lambda integration"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "default",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "${aws_lambda_function.cloudsearch_proxy.arn}",
      "Condition": {
        "ArnLike": {
          "AWS:SourceArn": "arn:aws:execute-api:eu-central-1:${var.account_number[terraform.workspace]}:${aws_api_gateway_rest_api.cloud_search_api_gw.id}/*"
        }
      }
    }
  ]
}
EOF
}

# deploy to the stage
resource "aws_api_gateway_deployment" "deployment_suggest" {
  rest_api_id = "${aws_api_gateway_rest_api.cloud_search_api_gw.id}"
  stage_name  = "suggest"

  variables {
    # change below to trigger a stage deployment
    deployed_at = "1.0"
  }
}

output "api_gateway_invoke_suggest_url" {
  value = "${aws_api_gateway_deployment.deployment_suggest.invoke_url}"
}

# deploy to the stage
resource "aws_api_gateway_deployment" "deployment_search" {
  rest_api_id = "${aws_api_gateway_rest_api.cloud_search_api_gw.id}"
  stage_name  = "search"

  variables {
    # change below to trigger a stage deployment
    deployed_at = "1.0"
  }
}

output "api_gateway_invoke_search_url" {
  value = "${aws_api_gateway_deployment.deployment_search.invoke_url}"
}

output "api_gateway_invoke_search_example_url" {
  value = "${aws_api_gateway_deployment.deployment_search.invoke_url}?getfields=*&num=100&q=searchParameter"
}

/* ==== END - API Gateway Creation ==== */

