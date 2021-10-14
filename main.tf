locals {
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
}


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

  //   route = [
  //     {
  //       cidr_block                 = "0.0.0.0/0"
  //       gateway_id                 = aws_internet_gateway.igw.id
  //       egress_only_gateway_id     = ""
  //       instance_id                = ""
  //       ipv6_cidr_block            = ""
  //       nat_gateway_id             = ""
  //       network_interface_id       = ""
  //       transit_gateway_id         = ""
  //       vpc_peering_connection_id  = ""
  //       carrier_gateway_id         = ""
  //       destination_prefix_list_id = ""
  //       local_gateway_id           = ""
  //       vpc_endpoint_id            = ""
  //     }
  //   ]
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