provider "aws" {
    region = "eu-north-1"
}

locals {
  ubuntu_ami = "ami-0ff338189efb7ed37"
}

resource "aws_vpc" "my_vpc" {
    cidr_block = "10.0.0.0/24"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags = {
        Name = "Terraform VPC"
    }
}

resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_subnet" "my_pub_subnet" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.128/25"
}

resource "aws_route_table" "my_public" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  } 
}

resource "aws_route_table_association" "my_route_table_association" {
  subnet_id = aws_subnet.my_pub_subnet.id
  route_table_id = aws_route_table.my_public.id
}

resource "aws_security_group" "asg_sg" {
    vpc_id      = aws_vpc.my_vpc.id

    ingress {
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        cidr_blocks     = ["0.0.0.0/0"]
    }

    # ingress {
    #     from_port       = 0
    #     to_port         = 27017
    #     protocol        = "-1"
    #     cidr_blocks     = ["0.0.0.0/0"]
    # }

    # ingress {
    #     from_port       = 0
    #     to_port         = 27018
    #     protocol        = "-1"
    #     cidr_blocks     = ["0.0.0.0/0"]
    # }

    # ingress {
    #     from_port       = 0
    #     to_port         = 27019
    #     protocol        = "-1"
    #     cidr_blocks     = ["0.0.0.0/0"]
    # }

    ingress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }

    egress {
        from_port        = 0
        to_port          = 0
        protocol         = "-1"
        cidr_blocks      = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
}

resource "aws_instance" "config_server" {
    ami = local.ubuntu_ami

    security_groups = [ aws_security_group.asg_sg.id ]
    user_data = file("${path.module}/config_server_startup.yml")
    instance_type = "t3.micro"

    key_name = "mn-key"
    associate_public_ip_address = true

    subnet_id = aws_subnet.my_pub_subnet.id
}

resource "aws_instance" "mongos" {
    ami = local.ubuntu_ami

    security_groups = [ aws_security_group.asg_sg.id ]
    user_data = templatefile("${path.module}/mongos_startup.yml", {cfg-primary = aws_instance.config_server.public_dns})
    instance_type = "t3.micro"

    key_name = "mn-key"
    associate_public_ip_address = true

    source_dest_check = false
    subnet_id = aws_subnet.my_pub_subnet.id
}

resource "aws_launch_configuration" "shard_launch_config" {
  image_id = local.ubuntu_ami
  security_groups = [ aws_security_group.asg_sg.id ]
  user_data = templatefile("${path.module}/shard_startup.yml", {cfg-primary = aws_instance.config_server.public_dns})
  instance_type = "t3.micro"

  key_name = "mn-key"
  associate_public_ip_address = true
}

resource "aws_autoscaling_group" "shards_asg" {
  name = "my-asg"
  vpc_zone_identifier = [ aws_subnet.my_pub_subnet.id ]
  launch_configuration = aws_launch_configuration.shard_launch_config.name

  desired_capacity = var.cluster_size
  min_size = 1
  max_size = 100

  health_check_grace_period = 300
  health_check_type = "EC2"
}

output "public_dns_config_server" {
  value = aws_instance.config_server.public_dns
}

output "public_dns_mongos" {
  value = aws_instance.mongos.public_dns
}