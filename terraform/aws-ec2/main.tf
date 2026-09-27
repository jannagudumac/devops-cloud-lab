provider "aws" {
  region = var.aws_region
  profile = "terraform-lab"
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Student DevOps lab security group"

  ingress {
    description = "HTTP application"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = var.project_name
  }
}

resource "aws_instance" "app" {
  
  ami                    = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.app.id]

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    docker pull ghcr.io/jannagudumac/devops-cloud-lab:latest

    docker run -d \
      --name devops-cloud-lab \
      --restart unless-stopped \
      -p 8080:8080 \
      ghcr.io/jannagudumac/devops-cloud-lab:latest
  EOF
  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}
