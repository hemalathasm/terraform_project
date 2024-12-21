resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr_block
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.sub1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "web-sg" {
  name = "web_sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "my-hema-test-bucket"
}

resource "aws_instance" "server1" {
  ami = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id = aws_subnet.sub1.id
  key_name = "padma"
  #user_data = base64decode(file("userdata.sh"))
}

resource "aws_instance" "server2" {
  ami = "ami-0e2c8caa4b6378d8c"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web-sg.id]
  subnet_id = aws_subnet.sub2.id
  key_name = "padma"
  #user_data = base64decode(file("userdata1.sh"))
}

resource "aws_lb" "my-lb" {
  name = "my-alb"
  internal = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.web-sg.id]
  subnets = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    name = "web"
  }
}

resource "aws_lb_target_group" "tg" {
  name = "my-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.my_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.server1.id
  port = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id = aws_instance.server2.id
  port = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.my-lb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type = "forward"
  }
}

output "load-balancer-output" {
  value = aws_lb.my-lb.dns_name
}