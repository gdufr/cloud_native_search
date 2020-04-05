/* ==== BEGIN - EC2 build server Creation ==== */
# this will use the local id_rsa.pub to set up ssh access for the build server
variable "key_path" {
  default = "~/.ssh/id_rsa.pub"
}

resource "aws_key_pair" "ssh_key_build_server" {
  key_name   = "EC2 ssh key"
  public_key = "${file(var.key_path)}"
}

resource "aws_iam_instance_profile" "build_server_instance_profile" {
  name = "cloud_search_build_server_instance_profile"
  role = "${aws_iam_role.build_server_role.name}"
}

output "build_server_instance_profile_arn" {
  value = "${aws_iam_instance_profile.build_server_instance_profile.arn}"
}

# create the role for the build server
resource "aws_iam_role" "build_server_role" {
  name = "cloud_search_build_server_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  description = "Allows build server instance to call s3, cloudwatch, and cloudsearch."
}

# attach AWS managed policy for SSM to build server role
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = "${aws_iam_role.build_server_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# attach AWS managed policy for EMR to build server role
resource "aws_iam_role_policy_attachment" "ec2_emr" {
  role       = "${aws_iam_role.build_server_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

# attach AWS managed policy for cloudsearch to build server role
resource "aws_iam_role_policy_attachment" "ec2_cloudsearch" {
  role       = "${aws_iam_role.build_server_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudSearchFullAccess"
}

# policy to allow build server to modify cluster
resource "aws_iam_policy" "ec2_emr_cluster_management" {
  name        = "ec2_emr_management_policy"
  description = "Allow access to cluster modification"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["elasticmapreduce:ModifyInstanceGroups"],
      "Resource": "*"
    }
  ]
}
EOF
}

# attach ec2_emr_cluster_management policy to build server role
resource "aws_iam_role_policy_attachment" "ec2_emr_cluster_management" {
  role       = "${aws_iam_role.build_server_role.name}"
  policy_arn = "${aws_iam_policy.ec2_emr_cluster_management.arn}"
}

# pulls the latest aws ami 
data "aws_ami" "aws" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-hvm*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"] # AWS
}

output "ami" {
  value = "${data.aws_ami.aws.id}"
}

/*
# build server is currently commented out, but can be uncommented if needed
resource "aws_instance" "build_server" {
  ami                  = "${data.aws_ami.aws.id}"
  instance_type        = "t2.small"
  iam_instance_profile = "${aws_iam_instance_profile.build_server_instance_profile.name}"

  associate_public_ip_address = true

  #TODO: use a separate key for the build server and EMR?
  key_name = "${aws_key_pair.emr.key_name}"

  vpc_security_group_ids = ["${aws_security_group.allow_ssh.id}"]
  subnet_id              = "${aws_subnet.main.id}"

  root_block_device = {
    volume_size = 50
  }

  #  user_data = "${file("../files/ec2/user_data.sh")}"

  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
}

output "build_server_public_ip" {
  value = "${aws_instance.build_server.public_ip}"
}
output "build_server_instance_id" {
  value = "${aws_instance.build_server.id}"
}
*/


/* ==== END - EC2 build server Creation ==== */

