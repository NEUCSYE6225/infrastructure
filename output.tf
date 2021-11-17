// output "vpc_id" {
//   value = aws_vpc.vpc.id
// }

// output "subnet_id" {
//   value = aws_subnet.subnet.*.id
// }

// output "igw_id" {
//   value = aws_internet_gateway.igw.id
// }

// output "public_route_table_id" {
//   value = aws_route_table.public.id
// }

// output "public_route_table_association_id" {
//   value = aws_route_table_association.public_subnet.*.id
// }

// output "public_route" {
//   value = aws_route_table.public.route.id
// }

output "S3_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "ami_id" {
  value = data.aws_ami.ami.id
}

// output "ec_id" {
//   value = aws_instance.ec2.public_ip
// }