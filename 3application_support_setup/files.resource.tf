######  BEGIN - cloudsearch doc endpoint data source
# the index-writer.xml and nutch-site.xml use the cloudsearch doc endpoint
data "template_file" "doc_endpoint" {
  template = "${file("../files/cloudsearch/cs_doc_endpoint.txt")}"
}

output "cs_doc_endpoint" {
  value = "${data.template_file.doc_endpoint.rendered}"
}

######  END - cloudsearch doc endpoint data source

######  BEGIN - cloudsearch search endpoint data source
data "template_file" "search_endpoint" {
  template = "${file("../files/cloudsearch/cs_search_endpoint.txt")}"
}

output "cs_search_endpoint" {
  value = "${data.template_file.search_endpoint.rendered}"
}

######  END - cloudsearch search endpoint data source

######  BEGIN - index_writer
# this takes in the template index writers file and replaces the cs_doc_endpoint placeholder with
# the contents of the output file from the custom provider in ../2cloudsearch_setup/cloudsearch.resource.tf
data "template_file" "index_writer" {
  template = "${file("../files/hadoop/nutch/conf/index_writer_template.xml")}"

  vars = {
    cs_doc_endpoint = "${chomp(data.template_file.doc_endpoint.rendered)}"
    cs_doc_region   = "${var.region}"
  }
}

resource "local_file" "index_writer" {
  content  = "${data.template_file.index_writer.rendered}"
  filename = "../files/hadoop/nutch/conf/index_writer_rendered.xml"
}

######  END - index_writer

######  BEGIN - nutch_site
# this takes in the template nutch site file and replaces the cs_doc_endpoint placeholder with
# the contents of the output file from the custom provider in ../2cloudsearch_setup/cloudsearch.resource.tf
data "template_file" "nutch_site" {
  template = "${file("../files/hadoop/nutch/conf/nutch_site_template.xml")}"

  vars = {
    cs_doc_endpoint = "${chomp(data.template_file.doc_endpoint.rendered)}"
    cs_doc_region   = "${var.region}"
  }
}

resource "local_file" "nutch_site" {
  content  = "${data.template_file.nutch_site.rendered}"
  filename = "../files/hadoop/nutch/conf/nutch_site_rendered.xml"
}

######  END - nutch_site

######  BEGIN - master_bootstrap
# this takes in the template master bootstrap file and replaces the cs_doc_endpoint and cs_search_endpoint placeholders with
# the contents of the output files from the custom provider in ../2cloudsearch_setup/cloudsearch.resource.tf
# it also writes the seed file into the master_bootstrap for copying into the hdfs
data "template_file" "url_seed" {
  template = "${file("../files/urls/seed.txt")}"
}

data "template_file" "master_bootstrap" {
  template = "${file("../files/hadoop/master_bootstrap_template.sh")}"

  vars = {
    cs_doc_endpoint                 = "${chomp(data.template_file.doc_endpoint.rendered)}"
    cs_search_endpoint              = "${chomp(data.template_file.search_endpoint.rendered)}"
    url_seed                        = "${chomp(data.template_file.url_seed.rendered)}"
    application_support_bucket_name = "${aws_s3_bucket.s3.bucket}"
  }
}

resource "local_file" "master_bootstrap" {
  content  = "${data.template_file.master_bootstrap.rendered}"
  filename = "../files/hadoop/master_bootstrap_rendered.sh"
}

output "master_bootstrap_path" {
  value = "${local_file.master_bootstrap.filename}"
}

######  END - master_bootstrap

######  BEGIN - api gateway swagger
# During development it was much simpler to set up the gateway in the console and then export it
# the exported swagger yaml then gets the variables manually inserted to render from the template here
data "template_file" "api_gateway_swagger" {
  template = "${file("../files/api_gateway/apigateway_swagger_template.yaml")}"

  vars {
    lambda_invoke_arn = "${aws_lambda_function.cloudsearch_proxy.invoke_arn}"
    title             = "${var.api_gateway_title[terraform.workspace]}"
  }
}

# render it with the variables populated
resource "local_file" "api_gateway_swgger" {
  content  = "${data.template_file.api_gateway_swagger.rendered}"
  filename = "../files/api_gateway/apigateway_swagger_rendered.yaml"
}

######  END - api gateway swagger

######  BEGIN - run_crawler creation
data "template_file" "run_crawler" {
  template = "${file("../files/hadoop/nutch/run_crawler_template.sh")}"

  vars {
    application_support_bucket_name = "${aws_s3_bucket.s3.bucket}"
  }
}

# render it with the variables populated
resource "local_file" "run_crawler" {
  content  = "${data.template_file.run_crawler.rendered}"
  filename = "../files/hadoop/nutch/run_crawler_rendered.sh"
}

output "run_crawler_path" {
  value = "${local_file.run_crawler.filename}"
}

######  END - run_crawler creation

