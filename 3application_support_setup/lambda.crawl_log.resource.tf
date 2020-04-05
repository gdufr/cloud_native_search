resource "aws_lambda_function" "crawl_log" {
  function_name = "crawl_log"
  filename      = "${data.archive_file.lambda_crawl_log_zip.output_path}"
  handler       = "index.handler"
  role          = "${aws_iam_role.crawl_log_lambda_role.arn}"
  runtime       = "nodejs8.10"
  publish       = "false"
  timeout       = "10"
  memory_size   = "256"
  depends_on    = ["data.archive_file.lambda_crawl_log_zip"]
}

output "lambda_crawl_log_arn" {
  value = "${aws_lambda_function.crawl_log.arn}"
}

# zips the function for uploading to lambda
data "archive_file" "lambda_crawl_log_zip" {
  type        = "zip"
  output_path = "../files/lambda_zip/lambda_crawl_log.zip"

  source_dir = "../files/lambda/crawl_log"
}

# create role for lambda
resource "aws_iam_role" "crawl_log_lambda_role" {
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

  description = "Allows Lambda function to assume the required role."
}

# attach AWS managed policy for cloudwatch logging to lambda role
resource "aws_iam_role_policy_attachment" "crawl_log_cloudwatch_access" {
  role       = "${aws_iam_role.crawl_log_lambda_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# allow access to the lambda portion of the application bucket
resource "aws_iam_policy" "crawl_log_s3_access" {
  name        = "lambda_s3_crawl_log_access_policy"
  description = "Allow access to read the bucket /logs/* contents"

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
        "s3:GetObject",
        "s3:PutObject",
        "s3:PutBucketVersioning"
      ],
      "Resource": ["arn:aws:s3:::${var.application_shared_bucket_name[terraform.workspace]}/logs/*"]
    }
  ]
}
EOF
}

# attach s3 access policy to role
resource "aws_iam_role_policy_attachment" "crawl_log_s3_access" {
  role       = "${aws_iam_role.crawl_log_lambda_role.name}"
  policy_arn = "${aws_iam_policy.crawl_log_s3_access.arn}"
}

# allow S3 event to invoke the function
resource "aws_lambda_permission" "lambda_s3_permission" {
  statement_id  = "allow_s3_invoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.crawl_log.function_name}"
  principal     = "s3.amazonaws.com"

  source_arn = "${aws_s3_bucket.s3.arn}"
}
