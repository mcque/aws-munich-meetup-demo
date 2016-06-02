variable "aws_region" {
  default = "us-east-1"
}

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "aws_amis" {
  default = {
    ap-northeast-1 = "ami-d886a1b6"
    ap-southeast-1 = "ami-a17dbac2"
    eu-central-1   = "ami-99cad9f5"
    eu-west-1      = "ami-a317ced0"
    sa-east-1      = "ami-ae44ffc2"
    us-east-1      = "ami-f7136c9d"
    us-west-1      = "ami-44b1de24"
    cn-north-1     = "ami-a664f89f"
    us-gov-west-1  = "ami-30b8da13"
    ap-southeast-2 = "ami-067d2365"
    us-west-2      = "ami-46a3b427"
  }
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  default = "~/.ssh/id_rsa"
}

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

resource "aws_key_pair" "demo" {
  key_name   = "demo"
  public_key = "${file("${var.public_key_path}")}"
}

resource "aws_vpc" "demo" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    Name = "demo"
  }
}

resource "aws_subnet" "demo" {
  vpc_id                  = "${aws_vpc.demo.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "demo" {
  vpc_id = "${aws_vpc.demo.id}"
}

resource "aws_route" "demo" {
  route_table_id         = "${aws_vpc.demo.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.demo.id}"
}

resource "aws_security_group" "demo" {
  name   = "demo"
  vpc_id = "${aws_vpc.demo.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "demo" {
  name = "demo"

  subnets         = ["${aws_subnet.demo.id}"]
  security_groups = ["${aws_security_group.demo.id}"]
  instances       = ["${aws_instance.web.*.id}"]

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
}

resource "aws_instance" "web" {
  count = "5"

  ami           = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.demo.id}"

  vpc_security_group_ids = ["${aws_security_group.demo.id}"]
  subnet_id              = "${aws_subnet.demo.id}"

  tags {
    Name = "demo-${count.index}"
  }

  connection {
    user        = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    scripts = [
      "${path.module}/scripts/wait-for-ready.sh",
      "${path.module}/scripts/install-apache.sh",
    ]
  }

  provisioner "file" {
    source      = "${path.module}/scripts/index.html"
    destination = "/tmp/index.html"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo sed -i 's/AWS_IP_ADDRESS/${self.public_ip}/' /tmp/index.html",
      "sudo mv /tmp/index.html /var/www/html/index.html",
    ]
  }
}

output "address" {
  value = "${aws_elb.demo.dns_name}"
}
