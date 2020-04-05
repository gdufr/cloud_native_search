### BEGIN - EMR Hadoop cluster creation 
resource "aws_emr_cluster" "cluster" {
  name          = "cloud-native-search"
  release_label = "emr-5.19.0"
  applications  = ["Hadoop"]
  tags = "${merge(var.default_tags, map(
    "env", "${var.env[terraform.workspace]}"
  ))}"
  log_uri       = "s3n://${data.terraform_remote_state.3.application_support_bucket_name}/logs/"

  termination_protection            = false
  keep_job_flow_alive_when_no_steps = true

  lifecycle {
    ignore_changes = ["ec2_attributes.0.emr_managed_slave_security_group", "ec2_attributes.0.emr_managed_master_security_group", "instance_group"]
  }

  #  the master bootstrap log is showing 'hadoop command not found' when this is used
  #  apparently the operation occurs before the hadoop command is available on the cli
  #  this has been moved to the hadoop_setup below so it happens after the cluster setup is complete
  #  bootstrap_action {
  #    path = "${data.terraform_remote_state.3.master_bootstrap_s3_path}"
  #    name = "master_bootstrap.sh"
  #    args = ["instance.isMaster=true", "echo running master_bootstrap on master node"]
  #  }

  ec2_attributes {
    subnet_id                         = "${data.terraform_remote_state.3.subnet_id}"
    additional_master_security_groups = "${data.terraform_remote_state.3.inbound_security_group_id}"
    key_name                          = "${data.terraform_remote_state.3.keypair_name}"
    instance_profile                  = "${data.terraform_remote_state.3.build_server_instance_profile_arn}"
  }

  # the instance groups should be fine tuned based on project need
  instance_group {
    instance_role  = "MASTER"
    instance_type  = "m5.xlarge"
    instance_count = 1

    ebs_config {
      size                 = 100
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }
  instance_group {
    instance_role  = "CORE"
    instance_type  = "m5.xlarge"
    instance_count = 1

    ebs_config {
      size                 = 150
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }
  service_role = "${aws_iam_role.iam_emr_service_role.arn}"

# ideally the setup in null_resource.hadoop_setup below would be configured as steps
# but terraform doesn't currently support multiple steps
# since cluster debugging can only be enabled by a step it must be the only step
  step = {
    action_on_failure = "CONTINUE"
    name              = "enable cluster debugging"

    hadoop_jar_step {
      jar  = "command-runner.jar"
      args = ["state-pusher-script"]
    }
  }
}

### BEGIN - EMR Hadoop cluster creation 

output "emr_ssh_command" {
  value = "ssh hadoop@${aws_emr_cluster.cluster.master_public_dns}"
}

output "master_public_dns" {
  value = "${aws_emr_cluster.cluster.master_public_dns}"
}

output "master_security_group_id" {
  value = "${aws_emr_cluster.cluster.ec2_attributes.0.emr_managed_master_security_group}"
}

### BEGIN - files for scaling up and down
data "template_file" "scale_up" {
  template = "${file("../files/hadoop/scale_template.json")}"

  vars = {
    emr_node_count        = 6
    emr_instance_group_id = "${lookup(aws_emr_cluster.cluster.instance_group[0], "instance_role") == "CORE" ? lookup(aws_emr_cluster.cluster.instance_group[0], "id") : lookup(aws_emr_cluster.cluster.instance_group[1], "id")}"
    emr_cluster_id        = "${aws_emr_cluster.cluster.id}"
  }
}

resource "local_file" "scale_up" {
  content  = "${data.template_file.scale_up.rendered}"
  filename = "../files/hadoop/scale_up_rendered.json"
}

data "template_file" "scale_down" {
  template = "${file("../files/hadoop/scale_template.json")}"

  vars = {
    emr_node_count        = 1
    emr_instance_group_id = "${lookup(aws_emr_cluster.cluster.instance_group[0], "instance_role") == "CORE" ? lookup(aws_emr_cluster.cluster.instance_group[0], "id") : lookup(aws_emr_cluster.cluster.instance_group[1], "id")}"
    emr_cluster_id        = "${aws_emr_cluster.cluster.id}"
  }
}

resource "local_file" "scale_down" {
  content  = "${data.template_file.scale_down.rendered}"
  filename = "../files/hadoop/scale_down_rendered.json"
}

### END - files for scaling up and down
output "instance_groups" {
  value = "${aws_emr_cluster.cluster.instance_group}"
}

### BEGIN - file for crontab setup
data "template_file" "crontab_setup" {
  template = "${file("../files/hadoop/crontab_setup_template.sh")}"

  vars = {
    bucket = "${data.terraform_remote_state.3.application_support_bucket_name}"
  }
}

resource "local_file" "crontab_setup" {
  content  = "${data.template_file.crontab_setup.rendered}"
  filename = "../files/hadoop/crontab_setup_rendered.sh"
}

### END - file for crontab setup

### BEGIN - IAM roles and policies
resource "aws_iam_role" "iam_emr_service_role" {
  name = "iam_emr_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "iam_emr_service_policy" {
  name = "iam_emr_service_policy"
  role = "${aws_iam_role.iam_emr_service_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "cloudsearch:document",
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CancelSpotInstanceRequests",
            "ec2:CreateNetworkInterface",
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:DeleteNetworkInterface",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteTags",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstances",
            "ec2:DescribeKeyPairs",
            "ec2:DescribeNetworkAcls",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribePrefixLists",
            "ec2:DescribeRouteTables",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSpotInstanceRequests",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeVpcEndpoints",
            "ec2:DescribeVpcEndpointServices",
            "ec2:DescribeVpcs",
            "ec2:DetachNetworkInterface",
            "ec2:ModifyImageAttribute",
            "ec2:ModifyInstanceAttribute",
            "ec2:RequestSpotInstances",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RunInstances",
            "ec2:TerminateInstances",
            "ec2:DeleteVolume",
            "ec2:DescribeVolumeStatus",
            "ec2:DescribeVolumes",
            "ec2:DetachVolume",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListInstanceProfiles",
            "iam:ListRolePolicies",
            "iam:PassRole",
            "s3:CreateBucket",
            "s3:Get*",
            "s3:List*",
            "sdb:BatchPutAttributes",
            "sdb:Select",
            "sqs:CreateQueue",
            "sqs:Delete*",
            "sqs:GetQueue*",
            "sqs:PurgeQueue",
            "sqs:ReceiveMessage"
        ]
    }]
}
EOF
}

### END - IAM roles and policies

### BEGIN - hadoop setup
resource "null_resource" "hadoop_setup" {
  depends_on = ["aws_emr_cluster.cluster"]

  # execute this on terraform apply
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<EOF

while [ "$status" != "ok" ]
do

# check if a connection to the master node is possible, sleep if it's not
status=$(ssh -q -o StrictHostKeyChecking=no hadoop@"${aws_emr_cluster.cluster.master_public_dns}" echo ok 2>&1)
if [[ "$status" == "ok" ]] ; then

# the connection is available
echo "connection successful"

# scp required files to the cluster master 
		scp -q -o StrictHostKeyChecking=no "${data.terraform_remote_state.3.run_crawler_path}" hadoop@"${aws_emr_cluster.cluster.master_public_dns}":~/run_crawler.sh
		scp -q -o StrictHostKeyChecking=no "${local_file.scale_up.filename}" hadoop@"${aws_emr_cluster.cluster.master_public_dns}":~
		scp -q -o StrictHostKeyChecking=no "${local_file.scale_down.filename}" hadoop@"${aws_emr_cluster.cluster.master_public_dns}":~

# push the master_bootstrap and execute it
		scp -q -o StrictHostKeyChecking=no "${data.terraform_remote_state.3.master_bootstrap_path}" hadoop@"${aws_emr_cluster.cluster.master_public_dns}":~/master_bootstrap.sh
		ssh -q -o StrictHostKeyChecking=no hadoop@"${aws_emr_cluster.cluster.master_public_dns}" "sh ~/master_bootstrap.sh"

# push and execute the crontab setup script
		scp -q -o StrictHostKeyChecking=no ../files/hadoop/crontab_setup_rendered.sh hadoop@"${aws_emr_cluster.cluster.master_public_dns}":~/crontab_setup.sh
		ssh -q -o StrictHostKeyChecking=no hadoop@"${aws_emr_cluster.cluster.master_public_dns}" 'sh ~/crontab_setup.sh'
	break
elif [[ "$status" == "Permission denied"* ]] ; then
        echo no_auth
	echo "There was a permissions error when trying to connect to the hadoop cluster master.  Please verify that the local machine can connect and run the commands found in this resource, null_resource.hadoop_setup "
        break
else
	echo "waiting for connection to hadoop@${aws_emr_cluster.cluster.master_public_dns}"
        sleep 10
fi
done

EOF
  }
}
