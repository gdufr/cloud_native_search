/* ==== pull data from remote state ==== */
data "terraform_remote_state" "2" {
  backend = "s3"

  config {
    bucket = "${var.state_bucket_name[terraform.workspace]}"
    key    = "workspace/${var.env[terraform.workspace]}/cloudsearch_setup.tfstate"
    region = "${var.region}"
  }
}
