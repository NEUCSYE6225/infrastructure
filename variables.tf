variable "ec2username" {
  type        = string
  description = "aws_iam_user_ec2user"
}

variable "ec2userpolicyname" {
  type        = string
  description = "name of ec2 policy"
}

// variable "ec2policy" {
//   description = "policy of ec2"
// }

variable "vpc_name" {
  type        = string
  description = "Name of VPC"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR for VPC"
}

variable "subnet_cidr_block" {
  type        = list(string)
  description = "CIDR for VPC subnet"
  validation {
    condition     = length(var.subnet_cidr_block) == 3
    error_message = "Must create 3 subnets."
  }
}

variable "subnet_availability_zone" {
  type        = list(string)
  description = "availability zone for VPC subnet"
  validation {
    condition     = length(var.subnet_availability_zone) == 3
    error_message = "Must create 3 availability zones for subnet."
  }
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "enable_dns_hostnames (True/False)"
}

variable "enable_dns_support" {
  type        = bool
  description = "enable_dns_support (True/False)"
}

variable "enable_classiclink_dns_support" {
  type        = bool
  description = "enable_classiclink_dns_support (True/False)"
}

variable "assign_generated_ipv6_cidr_block" {
  type        = bool
  description = "assign_generated_ipv6_cidr_block (True/False)"
}

variable "map_public_ip_on_launch" {
  type        = bool
  description = "map_public_ip_on_launch (True/False)"
}

variable "default_destination_cidr_block" {
  type        = string
  description = "default_destination_cidr_block"
}

variable "ingress_ports" {
  type        = list(number)
  description = "list of ingress ports"
}
variable "url" {
  type        = string
  description = "url"
}
variable "db_instance_class" {
  type        = string
  description = "db_instance_class"
}
variable "db_identifier" {
  type        = string
  description = "db_identifier"
}
variable "db_username" {
  type        = string
  description = "db_username"
}
variable "db_password" {
  type        = string
  description = "db_password"
}
variable "db_name" {
  type        = string
  description = "db_name"
}
variable "db_engine_version" {
  type        = string
  description = "db_engine_version"
}
variable "db_owner" {
  type        = string
  description = "db_owner"
}

variable "ec2_instance_type" {
  type        = string
  description = "ec2_instance_type"
}
variable "ec2_volume_type" {
  type        = string
  description = "ec2_volume_type"
}
variable "ec2_volume_size" {
  description = "ec2_volume_size"
}
variable "ec2_delete_on_termination" {
  type        = bool
  description = "ec2_delete_on_termination"
}
variable "ec2_key_name" {
  type        = string
  description = "ec2_key_name"
}

variable "codedeploy_url" {
  type        = string
  description = "codedeploy url"
}

variable "codedeploy_region" {
  type        = string
  description = "region of codedeploy"
}

variable "codedeploy_application_name" {
  type        = string
  description = "CODE_DEPLOY_APPLICATION_NAME"
}
variable "profile" {
  type        = string
  description = "profile"
}