# Creatting vpc 

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "my-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public-2"
  }
}

# Private Subnets
resource "aws_subnet" "private-1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-1"
  }
}

resource "aws_subnet" "private-2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-2"
  }
}
# Main Internet Gateway for VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}
# Route Table for Public Subnet
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}
# Association between Public Subnet and Public Route Table
resource "aws_route_table_association" "public-assoc-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public-rt.id
}
resource "aws_route_table_association" "public-assoc-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public-rt.id
}
# Route Table for Private Subnet via nat-gw-1
resource "aws_route_table" "private-rt-1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw-1.id
  }

  tags = {
    Name = "Private Route Table-1"
  }
}
# Route Table for Private Subnet via nat-gw-2
resource "aws_route_table" "private-rt-2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat-gw-2.id
  }

  tags = {
    Name = "Private Route Table-2"
  }
}
# Association between Private Subnet and Private Route Table
resource "aws_route_table_association" "private-assoc-1" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.private-rt-1.id
}

resource "aws_route_table_association" "private-assoc-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private-rt-2.id
}
# Elastic IP for NAT Gateway public-1
resource "aws_eip" "nat_eip-1" {
  domain        = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT Gateway EIP public-1"
  }
}

# NAT Gateway for public-1
resource "aws_nat_gateway" "nat-gw-1" {
  allocation_id = aws_eip.nat_eip-1.id
  subnet_id     = aws_subnet.public-1.id

  tags = {
    Name = "NAT Gateway Public-1"
  }
}

# Elastic IP for NAT Gateway public-2
resource "aws_eip" "nat_eip-2" {
  domain        = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = {
    Name = "NAT Gateway EIP public-2"
  }
}

# NAT Gateway for public-2
resource "aws_nat_gateway" "nat-gw-2" {
  allocation_id = aws_eip.nat_eip-2.id
  subnet_id     = aws_subnet.public-2.id

  tags = {
    Name = "NAT Gateway Public-2"
  }
}
# Security Group
resource "aws_security_group" "my_sg" {
  name        = "my-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow http from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow http from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow outgoing traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-sg"
  }
}
#  Application Load Balancer
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]
}

# Load balancer Listener
resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
}

resource "aws_lb_target_group" "my_tg" {
  name     = "my-tg"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
health_check {
    enabled             = true
    interval            = 30
    path                = "/index.html"
    timeout             = 5
    matcher             = "200,202"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Create a Route53 hosted zone for your DNS website domain name
resource "aws_route53_zone" "thenovices" {
  name = "hoangguruu.id.vn"
}

# Create an A record that maps the domain name to your load balancer
resource "aws_route53_record" "thenovices" {
  zone_id = aws_route53_zone.thenovices.zone_id
  name = "hoangguruu.id.vn"
  type = "A"
  alias {
    name = aws_lb.my_alb.dns_name
    zone_id = aws_lb.my_alb.zone_id
    evaluate_target_health = true
  }
}
# Launch Template
resource "aws_launch_template" "my_launch_template" {
  name = "my_launch_template"

  image_id      = "ami-0947d2ba12ee1ff75"
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.my_sg.id]
  }

  user_data = filebase64("${path.module}/web.sh")
}

# Create a blue Auto Scaling Group
resource "aws_autoscaling_group" "blue" {
  name               = "blue_asg"
  max_size           = 3
  min_size           = 1
  health_check_type  = "ELB"
  desired_capacity   = 2
  target_group_arns  = [aws_lb_target_group.my_tg.arn]

  vpc_zone_identifier = [aws_subnet.public-1.id, aws_subnet.public-2.id]

  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale_up"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.blue.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"    # add one instance
  cooldown               = "300"  # cooldown period after scaling
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm" {
  alarm_name          = "scale-up-alarm"
  alarm_description   = "asg-scale-up-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.blue.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.blue.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm" {
  alarm_name          = "asg-scale-down-alarm"
  alarm_description   = "asg-scale-down-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.blue.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down.arn]
}

#  Green Auto Scaling Group
resource "aws_autoscaling_group" "green" {
  name               = "green_asg"
  max_size           = 2
  min_size           = 2
  health_check_type  = "ELB"
  desired_capacity   = 0
  target_group_arns  = [aws_lb_target_group.my_tg.arn]
  vpc_zone_identifier = [aws_subnet.public-1.id, aws_subnet.public-2.id]

  launch_template {
    id      = aws_launch_template.my_launch_template.id
    version = "$Latest"
  }
}


resource "aws_autoscaling_policy" "scale_up_green" {
  name                   = "scale_up"
  policy_type            = "SimpleScaling"
  autoscaling_group_name = aws_autoscaling_group.green.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"    # add one instance
  cooldown               = "300"  # cooldown period after scaling
}

resource "aws_cloudwatch_metric_alarm" "scale_up_alarm_green" {
  alarm_name          = "scale-up-alarm"
  alarm_description   = "asg-scale-up-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.green.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_up.arn]
}

resource "aws_autoscaling_policy" "scale_down_green" {
  name                   = "asg-scale-down"
  autoscaling_group_name = aws_autoscaling_group.green.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_down_alarm_green" {
  alarm_name          = "asg-scale-down-alarm"
  alarm_description   = "asg-scale-down-cpu-alarm"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"
  dimensions = {
    "AutoScalingGroupName" = aws_autoscaling_group.green.name
  }
  actions_enabled = true
  alarm_actions   = [aws_autoscaling_policy.scale_down.arn]
}

#  IAM Instance Profile
resource "aws_iam_instance_profile" "my_instance_profile" {
  name = "my-instance-profile"
}

#  Load balancer Listener Rule
resource "aws_lb_listener_rule" "blue_rule" {
  listener_arn = aws_lb_listener.my_lb_listener.arn
  priority      = 1
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
  condition {
      host_header {
      values = ["blue.hoangguruu.id.vn"]
    }
  }
}

resource "aws_lb_listener_rule" "green_rule" {
  listener_arn = aws_lb_listener.my_lb_listener.arn
  priority      = 2 
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_tg.arn
  }
  condition {
    host_header {
      values = ["green.hoangguruu.id.vn"]
    }
  }
}

# Create a AWS RDS_mysql

resource "aws_db_instance" "myrds" {
  allocated_storage   = 20
  storage_type        = "gp2"
  identifier          = "rdstf"
  engine              = "mysql"
  engine_version      = "8.0.33"
  instance_class      = "db.t3.micro" # Adjust instance class
  username            = "yotlaire"
  password            = "guilloux"
  publicly_accessible = false # Adjust as needed
  skip_final_snapshot = true    # Create final snapshot on deletion
  db_subnet_group_name = aws_db_subnet_group.my_subnet_group.name
  
  tags = {
    Name = "MyRDS"
  }
}
resource "aws_db_subnet_group" "my_subnet_group" {
  name       = "my-db-subnet-group"
  description = "My DB subnet group"
  subnet_ids = [aws_subnet.private-1.id, aws_subnet.private-2.id] 
}

