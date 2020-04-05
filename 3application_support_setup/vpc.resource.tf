resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

resource "aws_subnet" "main" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "10.0.1.0/24"

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

resource "aws_route_table_association" "a" {
  subnet_id      = "${aws_subnet.main.id}"
  route_table_id = "${aws_route_table.r.id}"
}

output "subnet_id" {
  value = "${aws_subnet.main.id}"
}

resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}
