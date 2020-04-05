# Dynamo table for terraform remote state locking
resource "aws_dynamodb_table" "table" {
  name           = "${var.state_bucket_name[terraform.workspace]}"
  hash_key       = "LockID"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}
