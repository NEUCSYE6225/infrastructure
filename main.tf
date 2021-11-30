locals {
  ec2username       = var.ec2username
  ec2userpolicyname = var.ec2userpolicyname
  // ec2policy                        = var.ec2policy
  name                             = var.vpc_name
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  enable_classiclink_dns_support   = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  map_public_ip_on_launch          = var.map_public_ip_on_launch
  vpc_cidr_block                   = trimspace(var.vpc_cidr_block)
  subnet_cidr_block                = var.subnet_cidr_block
  subnet_availability_zone         = var.subnet_availability_zone
  default_destination_cidr_block   = var.default_destination_cidr_block
  ingress_ports                    = var.ingress_ports
  db_instance_class                = var.db_instance_class
  db_identifier                    = var.db_identifier
  db_username                      = var.db_username
  db_password                      = var.db_password
  db_name                          = var.db_name
  db_engine_version                = var.db_engine_version

  db_owner = var.db_owner
}


// Create VPC
resource "aws_vpc" "vpc" {
  cidr_block                       = local.vpc_cidr_block
  enable_dns_hostnames             = local.enable_dns_hostnames
  enable_dns_support               = local.enable_dns_support
  enable_classiclink_dns_support   = local.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = local.assign_generated_ipv6_cidr_block
  tags = {
    Name = format("%s-VPC", local.name)
  }
}

resource "aws_subnet" "subnet" {
  depends_on = [aws_vpc.vpc]

  count                   = length(local.subnet_cidr_block)
  cidr_block              = local.subnet_cidr_block[count.index]
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = local.subnet_availability_zone[count.index]
  map_public_ip_on_launch = local.map_public_ip_on_launch
  tags = {
    Name = format("%s-Subnet[%s]", local.name, count.index)
  }
}

resource "aws_internet_gateway" "igw" {
  depends_on = [aws_vpc.vpc]
  vpc_id     = aws_vpc.vpc.id
  tags = {
    Name = format("%s-Gateway", local.name)
  }
}

resource "aws_route_table" "public" {

  depends_on = [aws_vpc.vpc, aws_internet_gateway.igw]

  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = format("%s-Public_Route_Table", local.name)
  }
}

resource "aws_route_table_association" "public_subnet" {
  depends_on = [aws_route_table.public, aws_subnet.subnet]

  count          = length(local.subnet_cidr_block)
  subnet_id      = aws_subnet.subnet[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = local.default_destination_cidr_block
  gateway_id             = aws_internet_gateway.igw.id
}

// create security group - application
resource "aws_security_group" "application" {
  name   = "application"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    iterator = port
    for_each = local.ingress_ports
    content {
      from_port        = port.value
      to_port          = port.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  ingress {
    from_port = 3000
    to_port   = 3000
    protocol  = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// create security group - database
resource "aws_security_group" "database" {
  name   = "database"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.application.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
// create S3
resource "random_string" "resource_code" {
  length  = 10
  special = false
  upper   = false
}
// resource "aws_kms_key" "mykey" {
//   description             = "This key is used to encrypt bucket objects"
//   deletion_window_in_days = 10
// }

resource "aws_s3_bucket" "bucket" {
  bucket = format("%s.%s.%s", random_string.resource_code.result, var.profile, var.url)
  acl    = "private"
  lifecycle_rule {
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        // kms_master_key_id = aws_kms_key.mykey.arn
        sse_algorithm = "AES256"
      }
    }
  }
}

// RDS Parameter Group
resource "aws_db_parameter_group" "default" {
  name   = "mysql"
  family = "mysql8.0"
  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
}

// create RDS Instance
resource "aws_db_instance" "default" {
  allocated_storage       = 10
  engine                  = "mysql"
  instance_class          = local.db_instance_class
  multi_az                = false
  identifier              = local.db_identifier
  engine_version          = local.db_engine_version
  username                = local.db_username
  password                = local.db_password
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.default.name
  vpc_security_group_ids  = ["${aws_security_group.database.id}"]
  name                    = local.db_name
  skip_final_snapshot     = true
  parameter_group_name    = aws_db_parameter_group.default.name
  availability_zone       = "us-east-1b"
  backup_retention_period = 1
}

resource "aws_db_subnet_group" "default" {
  name       = "aws_db_subnet_group"
  subnet_ids = ["${aws_subnet.subnet[1].id}", "${aws_subnet.subnet[2].id}"]
}

resource "aws_db_instance" "readreplica" {
  replicate_source_db = aws_db_instance.default.identifier
  instance_class      = local.db_instance_class
  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = true
  // db_subnet_group_name   = aws_db_subnet_group.default.name
  identifier             = "${local.db_name}-readreplica"
  vpc_security_group_ids = ["${aws_security_group.database.id}"]
  parameter_group_name   = aws_db_parameter_group.default.name
  availability_zone      = "us-east-1c"
}



// AMI image
data "aws_ami" "ami" {
  executable_users = ["self"]
  most_recent      = true
  owners           = ["${local.db_owner}"]
}

// resource "aws_instance" "ec2" {

//   depends_on = [
//     aws_db_instance.default
//   ]
//   ami           = data.aws_ami.ami.id
//   instance_type = "t2.micro"


//   root_block_device {
//     volume_type           = "gp2"
//     volume_size           = 20
//     delete_on_termination = true
//     encrypted             = true
//   }

//   ebs_block_device {
//     device_name           = "/dev/sda1"
//     delete_on_termination = true
//     volume_size           = 20
//     volume_type           = "gp2"
//     encrypted             = true
//   }
//   // iam_instance_profile        = aws_iam_instance_profile.ec2-s3.name
//   iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy.name
//   tags = {
//     Name = "WebApp"
//   }

//   associate_public_ip_address = true
//   subnet_id                   = aws_subnet.subnet[0].id
//   security_groups = [
//     "${aws_security_group.application.id}"
//   ]
//   key_name  = "csye6225"
//   user_data = <<EOF
// #!/bin/bash
// sudo mkdir /home/ubuntu/webapp
// sudo chmod 777 /home/ubuntu/webapp
// sudo touch /home/ubuntu/webapp/.env
// sudo echo "DATABASE_username = ${aws_db_instance.default.username}" >> /home/ubuntu/webapp/.env
// sudo echo "DATABASE_password = ${aws_db_instance.default.password}" >> /home/ubuntu/webapp/.env
// sudo echo "DATABASE_host = ${aws_db_instance.default.endpoint}" >> /home/ubuntu/webapp/.env
// sudo echo "DATABASE_name = ${aws_db_instance.default.name}" >> /home/ubuntu/webapp/.env
// sudo echo "Bucket_name = ${aws_s3_bucket.bucket.bucket}" >> /home/ubuntu/webapp/.env
// cd /home/ubuntu/webapp
// sudo npm init -y
// sudo npm install  --save body-parser express bcryptjs mysql uuid nodemon dotenv aws-sdk mime-types public-ip fs winston statsd-client
// sudo npm install pm2@latest -g
// ##### END OF USER DATA
//   EOF
// }

// create AMI user and policy

resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17"
    "Statement" = [
      {
        "Action" = "sts:AssumeRole"
        "Effect" = "Allow"
        "Sid"    = ""
        "Principal" = {
          "Service" = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "WebAppS3" {
  name = "WebAppS3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObjectAcl"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "EC2S3" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}
resource "aws_iam_instance_profile" "ec2-s3" {
  name = aws_iam_role.EC2-CSYE6225.name
  role = aws_iam_role.EC2-CSYE6225.name
}

resource "aws_iam_policy" "CodeDeploy_EC2_S3" {
  name = "CodeDeploy_EC2_S3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "s3:Get*",
          "s3:List*"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${var.codedeploy_url}",
          "arn:aws:s3:::${var.codedeploy_url}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "GH_Upload_To_S3" {
  name = "GH_Upload_To_S3"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:Get*",
          "s3:List*"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.codedeploy_url}",
          "arn:aws:s3:::${var.codedeploy_url}/*"
        ]
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "GH_Code_Deploy" {
  name = "GH_Code_Deploy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision"
        ],
        "Resource" : [
          "arn:aws:codedeploy:${var.codedeploy_region}:${data.aws_caller_identity.current.account_id}:application:${var.codedeploy_application_name}"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment"
        ],
        "Resource" : [
          "*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "codedeploy:GetDeploymentConfig"
        ],
        "Resource" : [
          "arn:aws:codedeploy:${var.codedeploy_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
          "arn:aws:codedeploy:${var.codedeploy_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
          "arn:aws:codedeploy:${var.codedeploy_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
        ]
      }
    ]
  })
}

data "aws_iam_user" "ghactions_app" {
  user_name = "ghactions-app"
}

resource "aws_iam_user_policy_attachment" "GH_Upload_To_S3_user" {
  user       = data.aws_iam_user.ghactions_app.user_name
  policy_arn = aws_iam_policy.GH_Upload_To_S3.arn
}

resource "aws_iam_user_policy_attachment" "GH_Code_Deploy_user" {
  user       = data.aws_iam_user.ghactions_app.user_name
  policy_arn = aws_iam_policy.GH_Code_Deploy.arn
}

resource "aws_iam_user_policy_attachment" "GH_Code_Deploy_Lambda_user" {
  user       = data.aws_iam_user.ghactions_app.user_name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = "CodeDeployEC2ServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CodeDeployEC2ServiceRole_EC2_S3_role" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = aws_iam_policy.CodeDeploy_EC2_S3.arn
}

resource "aws_iam_role_policy_attachment" "CodeDeployEC2ServiceRole_WebAppS3_role" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}

# For clouldwatch
resource "aws_iam_role_policy_attachment" "CodeDeployEC2ServiceRole_cloudwatch_role" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


resource "aws_iam_instance_profile" "ec2_codedeploy" {
  name = aws_iam_role.CodeDeployEC2ServiceRole.name
  role = aws_iam_role.CodeDeployEC2ServiceRole.name
}

resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "CodeDeployServiceRole"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : [
            "codedeploy.amazonaws.com"
          ]
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "CodeDeployRole" {
  role       = aws_iam_role.CodeDeployServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "csye6225_webapp" {
  name             = "csye6225-webapp"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "csye6225_webapp_deployment_group" {
  app_name              = aws_codedeploy_app.csye6225_webapp.name
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = aws_iam_role.CodeDeployServiceRole.arn
  autoscaling_groups    = [aws_autoscaling_group.autoscaling_group.name]
  deployment_style {
    deployment_type = "IN_PLACE"
  }
  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "WebApp"
    }
  }
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.webapp.name
    }
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }
}
data "aws_route53_zone" "zone" {
  name         = "${var.profile}.${var.url}"
  private_zone = false
}

// resource "aws_route53_record" "record" {
//   zone_id = data.aws_route53_zone.zone.id
//   name    = "${var.profile}.${var.url}"
//   type    = "A"
//   ttl     = "300"
//   records = [aws_instance.ec2.public_ip]
// }




resource "aws_launch_configuration" "asg_launch_config" {
  name          = "asg_launch_config"
  image_id      = data.aws_ami.ami.id
  instance_type = "t2.micro"
  key_name      = "csye6225"

  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_codedeploy.name

  security_groups = [
    "${aws_security_group.application.id}"
  ]

  user_data = <<EOF
#!/bin/bash
sudo mkdir /home/ubuntu/webapp
sudo chmod 777 /home/ubuntu/webapp
sudo touch /home/ubuntu/webapp/.env
sudo echo "DATABASE_username = ${aws_db_instance.default.username}" >> /home/ubuntu/webapp/.env
sudo echo "DATABASE_password = ${aws_db_instance.default.password}" >> /home/ubuntu/webapp/.env
sudo echo "DATABASE_host = ${aws_db_instance.default.endpoint}" >> /home/ubuntu/webapp/.env
sudo echo "DATABASE_read_host = ${aws_db_instance.readreplica.endpoint}" >> /home/ubuntu/webapp/.env
sudo echo "DATABASE_name = ${aws_db_instance.default.name}" >> /home/ubuntu/webapp/.env
sudo echo "Bucket_name = ${aws_s3_bucket.bucket.bucket}" >> /home/ubuntu/webapp/.env
sudo echo "SNS_topic = ${aws_sns_topic.sns_topic.arn}" >> /home/ubuntu/webapp/.env
cd /home/ubuntu/webapp
sudo npm init -y
sudo npm install  --save body-parser express bcryptjs mysql uuid nodemon dotenv aws-sdk mime-types public-ip fs winston statsd-client sequelize mysql2
sudo npm install pm2@latest -g
sudo touch /home/ubuntu/autoscaling_done.txt
sudo echo "done" >> /home/ubuntu/autoscaling_done.txt
##### END OF USER DATA
  EOF
}

resource "aws_autoscaling_group" "autoscaling_group" {
  depends_on = [aws_launch_configuration.asg_launch_config]

  name                      = "webapp_autoscaling_group"
  default_cooldown          = 60
  launch_configuration      = aws_launch_configuration.asg_launch_config.name
  max_size                  = 5
  min_size                  = 3
  desired_capacity          = 3
  health_check_grace_period = 180
  target_group_arns         = ["${aws_lb_target_group.webapp.arn}"]
  vpc_zone_identifier       = ["${aws_subnet.subnet[0].id}", "${aws_subnet.subnet[1].id}", "${aws_subnet.subnet[2].id}"]
  tag {
    key                 = "Name"
    value               = "WebApp"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "up" {
  name                   = "autoscaling_policy_up"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_autoscaling_policy" "down" {
  name                   = "autoscaling_policy_down"
  policy_type            = "SimpleScaling"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group.name
}

resource "aws_cloudwatch_metric_alarm" "alarm_cpu_high" {
  alarm_name          = "alarm_cpu_up_5_percent"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "5"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling_group.name}"
  }
  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.up.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "alarm_cpu_down" {
  alarm_name          = "alarm_cpu_down_3_percent"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "3"
  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.autoscaling_group.name}"
  }
  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.down.arn}"]
}

resource "aws_security_group" "lb_security_group" {
  name   = "loadbalancer_sc"
  vpc_id = aws_vpc.vpc.id
  dynamic "ingress" {
    iterator = port
    for_each = local.ingress_ports
    content {
      from_port        = port.value
      to_port          = port.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "loadbalancer" {
  name                       = "webapp-load-balancer"
  internal                   = false
  subnets                    = ["${aws_subnet.subnet[0].id}", "${aws_subnet.subnet[1].id}", "${aws_subnet.subnet[2].id}"]
  security_groups            = ["${aws_security_group.lb_security_group.id}"]
  ip_address_type            = "ipv4"
  enable_deletion_protection = false
}

resource "aws_lb_target_group" "webapp" {
  name        = "webapptargetgroup"
  port        = 3000
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.vpc.id
  health_check {
    port                = "3000"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    path                = "/healthcheck"
  }
}

resource "aws_lb_listener" "forward" {
  load_balancer_arn = aws_lb.loadbalancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
}


resource "aws_route53_record" "record" {
  depends_on = [aws_lb.loadbalancer]
  zone_id    = data.aws_route53_zone.zone.id
  name       = "${var.profile}.${var.url}"
  type       = "A"
  alias {
    name                   = aws_lb.loadbalancer.dns_name
    zone_id                = aws_lb.loadbalancer.zone_id
    evaluate_target_health = false
  }
}

resource "aws_sns_topic" "sns_topic" {
  name = "user_verification_topic"
}

resource "aws_iam_role_policy_attachment" "CodeDeployEC2ServiceRole_SNS_role" {
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role" "lambda" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_iam_basicexecution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_iam_ses" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_iam_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambda.name
}

resource "aws_iam_role_policy_attachment" "ec2_iam_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  // role       = aws_iam_role.EC2-CSYE6225.name
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
}

resource "aws_lambda_function" "lambda_function" {
  filename      = "index.js.zip"
  function_name = "webapp-lambda"
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
}

resource "aws_lambda_permission" "lambda_trigger" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}

resource "aws_sns_topic_subscription" "SNSSubscribe" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda_function.arn
}

resource "aws_dynamodb_table" "dynamodb" {
  name           = "webapp_csye6225"
  hash_key       = "username"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "username"
    type = "S"
  }
  ttl {
    attribute_name = "TimeToLive"
    enabled        = true
  }
  tags = {
    Name = "DynamoDB"
  }
}