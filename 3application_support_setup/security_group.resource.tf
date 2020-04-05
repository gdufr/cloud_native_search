/* ==== BEGIN - ingress security group ==== */
# get_my_ip assumes that ifconfig will work on the local machine
# if not, you'll have to find another way to generate your local ip address
# or update the ingress rule below another way
data "external" "retrieve_ip_address" {
  program = ["sh", "../files/tools/get_my_ip"]
}

output "ip" {
  value = "${data.external.retrieve_ip_address.result.ip}"
}

resource "aws_security_group" "allow_ssh_build_server" {
  name        = "allow_ssh_build_server"
  description = "Allow ssh inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  # allow ingress only from the current IP of the creator of the resource
  # if changing locations/users run terraform apply again to update
  # if get_my_ip doesn't work on your system you can temporarily hard-code your ip
  #   address (or 0.0.0.0/0) in the cidr block below and run terraform apply to gain access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.retrieve_ip_address.result.ip}/32"]
  }

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

output "inbound_security_group_id" {
  value = "${aws_security_group.allow_ssh_build_server.id}"
}

/* ==== END - ingress security group ==== */

resource "aws_security_group" "allow_all_outbound" {
  name        = "allow_all_outbound"
  description = "Allow all outbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "allow_outbound_security_group_id" {
  value = "${aws_security_group.allow_all_outbound.id}"
}

resource "aws_security_group" "allow_ssh" {
  name        = "AllowSSH"
  description = "Allow ssh inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  # allow ingress only from the current IP of the creator of the resource
  # if changing locations/users run terraform apply again to update
  # if get_my_ip doesn't work on your system you can temporarily hard-code your ip
  #   address (or 0.0.0.0/0) in the cidr block below and run terraform apply to gain access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

output "allow_ssh_security_group_id" {
  value = "${aws_security_group.allow_ssh.id}"
}
