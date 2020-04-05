provider "aws" {
  version = "~> 1.56.0"
  region  = "${var.region}"

  #  assume_role {
  #    role_arn     = "${var.workspace_iam_roles[terraform.workspace]}"
  #    session_name = "UpdateServices-${terraform.workspace}"
  #  }
}
