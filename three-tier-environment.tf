terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}

# Create a VPC
resource "aws_vpc" "kpmg-vpc" {
  cidr_block = "172.0.0.0/16"
  tags = {
    Name = "KPMG VPC"
  }
}

# Create Web Public Subnet
resource "aws_subnet" "web-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "172.32.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "kpmg-web-1a"
  }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "172.32.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "kpmg-web-2b"
  }
}

# Create Database Private Subnet
resource "aws_subnet" "database-subnet-1" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "172.32.3.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "kpmg-database-1a"
  }
}

resource "aws_subnet" "database-subnet-2" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "172.32.4.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "kpmg-database-2b"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "kpgm igw"
  }
}

# Create Web layber route table
resource "aws_route_table" "kpmg-web-rt" {
  vpc_id = aws_vpc.my-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "KPMG-WebRT"
  }
}

# Create Web Subnet association with Web route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.web-rt.id
}

#Create EC2 Instance
resource "aws_instance" "kpmg-webserver-1" {
  ami                    = "ami-011d03b8ddcef80fd"
  instance_type          = "t3.micro"
  availability_zone      = "us-east-2a"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-1.id
  user_data              = file("install_nginx.sh")

  tags = {
    Name = "KPMG Web Server"
  }

}

resource "aws_instance" "kpmg-webserver-2" {
  ami                    = "ami-011d03b8ddcef80fd"
  instance_type          = "t3.micro"
  availability_zone      = "us-east-2b"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-2.id
  user_data              = file("install_nginx.sh")

  tags = {
    Name = "KPMG Web Server"
  }

}

# Create Web Security Group
resource "aws_security_group" "kmpg-web-sg" {
  name        = "Web-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  dynamic "ingress" {
    for_each = [443, 80]
    iterator = port
    content = {
      description = "HTTP from VPC"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

}

egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}

tags = {
  Name = "KPMG-Web-SG"
}

# Create Database Security Group
resource "aws_security_group" "kpmg-database-sg" {
  name        = "KPMG-Database-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.my-vpc.id

  dynamic "ingress" {
    for_each = [3306, 27017]
    iterator = port
    content = {
      description = "DB from VPC"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }


  dynamic "egress" {
    for_each = [32768, 65535]
    iterator = port
    content = {
      description = "DB from VPC"
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = {
    Name = "KPMG-Database-SG"
  }
}

resource "aws_lb" "kpmg-external-elb" {
  name               = "KPMG-External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
}

resource "aws_lb_target_group" "kpmg-external-elb" {
  name     = "KPMG-ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "kpmg-external-elb1" {
  target_group_arn = aws_lb_target_group.kpmg-external-elb.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

  depends_on = [
    aws_instance.kmpg-webserver1,
  ]
}

resource "aws_lb_target_group_attachment" "kpmg-external-elb2" {
  target_group_arn = aws_lb_target_group.kpmg-external-elb.arn
  target_id        = aws_instance.webserver2.id
  port             = 80

  depends_on = [
    aws_instance.kmpg-webserver2,
  ]
}

resource "aws_lb_listener" "kpmg-external-elb" {
  load_balancer_arn = aws_lb.kpmg-external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kpmg-external-elb.arn
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.default.id
  engine                 = "mysql"
  engine_version         = "8.0.20"
  instance_class         = "db.t3.micro"
  multi_az               = true
  name                   = "kmpgdb"
  username               = "kmpgdb"
  password               = "kmpgdb$UK@PK"
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.kpmg-database-sg.id]
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.database-subnet-1.id, aws_subnet.database-subnet-2.id]

  tags = {
    Name = "KPMG DB Subnet Group"
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}