# takes the ~/.ssh/id_rsa.pub from the local computer and adds it as a key-pair to configure access to the build server and EMR cluster Master
resource "aws_key_pair" "emr" {
  key_name   = "emr-key"
  public_key = "${file("~/.ssh/id_rsa.pub")}"
}

output "keypair_name" {
  value = "${aws_key_pair.emr.key_name}"
}
