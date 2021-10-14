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