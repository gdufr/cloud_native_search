/* ==== create s3 to remotely store .tfstate in ==== */
resource "aws_s3_bucket" "s3" {
  bucket = "${var.state_bucket_name[terraform.workspace]}"

  acl           = "private"
  force_destroy = "true"
  region        = "${var.region}"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = ""
        sse_algorithm     = "AES256"
      }
    }
  }

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

output "state_bucket_name" {
  value = "${var.state_bucket_name[terraform.workspace]}"
}
