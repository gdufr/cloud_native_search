/* ==== BEGIN create s3 bucket for application configuration and logs ==== */
resource "aws_s3_bucket" "s3" {
  bucket = "${var.application_shared_bucket_name[terraform.workspace]}"

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

output "application_support_bucket_name" {
  value = "${var.application_shared_bucket_name[terraform.workspace]}"
}

/* ==== END create s3 bucket for application configuration and logs ==== */
/*
resource "aws_s3_bucket_object" "language_abbreviation_map" {
  bucket       = "${aws_s3_bucket.s3.bucket}"
  key          = "/lambda/ISO_639_1_language_abbreviations.json"
  source       = "../files/lambda/search/ISO_639_1_language_abbreviations.json"
  etag         = "${md5(file("../files/lambda/search/ISO_639_1_language_abbreviations.json"))}"
  content_type = "application/json"
}
*/

resource "aws_s3_bucket_object" "site_host_map" {
  bucket       = "${aws_s3_bucket.s3.bucket}"
  key          = "lambda/site_host_map.json"
  source       = "../files/lambda/site_host_map.json"
  etag         = "${md5(file("../files/lambda/site_host_map.json"))}"
  content_type = "application/json"
}

resource "aws_s3_bucket_object" "seed" {
  bucket = "${aws_s3_bucket.s3.bucket}"
  key    = "urls/seed.txt"
  source = "../files/urls/seed.txt"
  etag   = "${md5(file("../files/urls/seed.txt"))}"
}

resource "aws_s3_bucket_object" "index_writers_conf" {
  bucket  = "${aws_s3_bucket.s3.bucket}"
  key     = "hadoop/nutch/conf/index-writers.xml"
  content = "${data.template_file.index_writer.rendered}"
  etag    = "${md5(data.template_file.index_writer.rendered)}"
}

output "index_writers_s3_path" {
  value = "${format("s3://%s/%s",aws_s3_bucket_object.index_writers_conf.bucket, aws_s3_bucket_object.index_writers_conf.key )}"
}

resource "aws_s3_bucket_object" "regex_urlfilters_conf" {
  bucket  = "${aws_s3_bucket.s3.bucket}"
  key     = "hadoop/nutch/conf/regex-urlfilter.txt"
  content = "${file("../files/hadoop/nutch/conf/regex-urlfilter.txt")}"
  etag    = "${md5(file("../files/hadoop/nutch/conf/regex-urlfilter.txt"))}"
}

output "regex_urlfilters_s3_path" {
  value = "${format("s3://%s/%s",aws_s3_bucket_object.regex_urlfilters_conf.bucket, aws_s3_bucket_object.regex_urlfilters_conf.key )}"
}

resource "aws_s3_bucket_object" "nutch_site_conf" {
  bucket  = "${aws_s3_bucket.s3.bucket}"
  key     = "hadoop/nutch/conf/nutch-site.xml"
  content = "${data.template_file.nutch_site.rendered}"
  etag    = "${md5(data.template_file.nutch_site.rendered)}"
}

output "nutch_site_s3_path" {
  value = "${format("s3://%s/%s",aws_s3_bucket_object.nutch_site_conf.bucket, aws_s3_bucket_object.nutch_site_conf.key )}"
}

resource "aws_s3_bucket_object" "master_bootstrap" {
  bucket  = "${aws_s3_bucket.s3.bucket}"
  key     = "hadoop/master_bootstrap.sh"
  content = "${data.template_file.master_bootstrap.rendered}"
  etag    = "${md5(data.template_file.master_bootstrap.rendered)}"
}

output "master_bootstrap_s3_path" {
  value = "${format("s3://%s/%s",aws_s3_bucket_object.master_bootstrap.bucket, aws_s3_bucket_object.master_bootstrap.key )}"
}

resource "aws_s3_bucket_object" "run_crawler" {
  depends_on = ["local_file.run_crawler"]
  bucket     = "${aws_s3_bucket.s3.bucket}"
  key        = "hadoop/nutch/run_crawler.sh"
  content    = "${data.template_file.run_crawler.rendered}"
  etag       = "${md5(data.template_file.run_crawler.rendered)}"
}

output "run_crawler_s3_path" {
  value = "${format("s3://%s/%s",aws_s3_bucket_object.run_crawler.bucket, aws_s3_bucket_object.run_crawler.key )}"
}
