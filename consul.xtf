variable "atlas_environment" {}

variable "atlas_token" {}

module "consul" {
  source  = "github.com/sethvargo/tf-consul-atlas-join"
  ami     = "${lookup(var.aws_amis, var.aws_region)}"
  servers = 3

  subnet_id      = "${aws_subnet.demo.id}"
  security_group = "${aws_security_group.demo.id}"

  key_name         = "${aws_key_pair.demo.key_name}"
  private_key_path = "${var.private_key_path}"

  atlas_environment = "${var.atlas_environment}"
  atlas_token       = "${var.atlas_token}"
}
