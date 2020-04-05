/* ==== save terraform state in S3 ==== */
# The S3 bucket and dynamodb_table should match the var.state_bucket_name
terraform {
  backend "s3" {
    encrypt                     = true
    acl                         = "private"
    bucket                      = "terraform-state-lock-cloud-native-search-dev"
    region                      = "eu-central-1"
    key                         = "application_support_setup.tfstate"
    dynamodb_table              = "terraform-state-lock-cloud-native-search-dev"
    workspace_key_prefix        = "workspace"
    skip_credentials_validation = true
  }
}

output "State Bucket" {
  value = "${var.state_bucket_name[terraform.workspace]}/workspace/${terraform.workspace}/application_support_setup.tfstate"
}
