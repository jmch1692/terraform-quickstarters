variable "environment_name" {
    default = "test"
}
variable "project_name" {}
# vpc vars 
variable cidr_block_map {}
variable aws_region {}

/* VPC */
resource "aws_vpc" "main_vpc" {
    cidr_block = var.cidr_block_map["main_vpc_cidr"]
    enable_dns_support = true
    enable_dns_hostnames = true
    enable_classiclink = false
    enable_classiclink_dns_support = false
    tags = {
      Name = "main_vpc"
    }
}

/* Elastic IPs */
resource "aws_eip" "eip_nat_1a" {
  vpc = true
}

# Internet Gateway
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags =  {
    Name = "main_igw"
  }
}

/* NAT Gateways */
resource "aws_nat_gateway" "natgw_1a" {
    allocation_id = aws_eip.eip_nat_1a.id
    subnet_id = aws_subnet.subnet_1a_public.id
    tags = {
      Name = "natgw_1a"
    }
}

/* Private Subnets */
resource "aws_subnet" "subnet_1a_serverless" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.cidr_block_map["subnet_cidr_serverless_1a"]
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "subnet_1a_serverless"
  }
}

resource "aws_subnet" "subnet_1a_datastore" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.cidr_block_map["subnet_cidr_datastore_1a"]
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "subnet_1a_datastore"
  }
}

resource "aws_subnet" "subnet_1b_datastore" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.cidr_block_map["subnet_cidr_datastore_1b"]
  availability_zone = "${var.aws_region}b"
  tags = {
    Name = "subnet_1b_datastore"
  }
}

resource "aws_subnet" "subnet_1a_app" {
  vpc_id = aws_vpc.main_vpc.id
  cidr_block = var.cidr_block_map["subnet_cidr_app_1a"]
  availability_zone = "${var.aws_region}a"
  tags = {
    Name = "subnet_1a_app"
  }
}

/* Public Subnets */
resource "aws_subnet" "subnet_1a_public" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.cidr_block_map["subnet_cidr_public_1a"]
  availability_zone       = "${var.aws_region}a"
  tags =  {
    Name = "subnet_1a_public"
  }
}
resource "aws_subnet" "subnet_1b_public" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.cidr_block_map["subnet_cidr_public_1b"]
  availability_zone       = "${var.aws_region}b"
  tags =  {
    Name = "subnet_1b_public"
  }
}
# Public subnet - Route Tables
resource "aws_route_table" "public_rtbl" {
  vpc_id = aws_vpc.main_vpc.id
  route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main_igw.id
  }
  tags =  {
    Name = "public_rtbl"
  }
}

# Private Subnet - Route tables
resource "aws_route_table" "private_rtbl_1a" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgw_1a.id
  }
  tags = {
    Name = "private_rtbl_1a"
  }
  #Added to avoid terraform plan inconsistencies. Remove if route ever needs to be changed
  lifecycle {
    ignore_changes = [
      route
    ]
  }
}

#Route table associations - Public
resource "aws_route_table_association" "rtbl_assoc_1a_public" {
  subnet_id      = aws_subnet.subnet_1a_public.id
  route_table_id = aws_route_table.public_rtbl.id
}
resource "aws_route_table_association" "rtbl_assoc_1b_public" {
  subnet_id     = aws_subnet.subnet_1b_public.id
  route_table_id = aws_route_table.public_rtbl.id
}

resource "aws_route_table_association" "rtbl_assoc_1a_datastore" {
  subnet_id       = aws_subnet.subnet_1a_datastore.id
  route_table_id  = aws_route_table.private_rtbl_1a.id
}

resource "aws_route_table_association" "rtbl_assoc_1b_datastore" {
  subnet_id       = aws_subnet.subnet_1b_datastore.id
  route_table_id  = aws_route_table.private_rtbl_1a.id
}

resource "aws_route_table_association" "rtbl_assoc_1a_app" {
  subnet_id       = aws_subnet.subnet_1a_app.id
  route_table_id  = aws_route_table.private_rtbl_1a.id
}

resource "aws_route_table_association" "rtbl_assoc_1a_serverless" {
  subnet_id       = aws_subnet.subnet_1a_serverless.id
  route_table_id  = aws_route_table.private_rtbl_1a.id
}

# VPC Endpoint
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id       = aws_vpc.main_vpc.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [aws_route_table.private_rtbl_1a.id]#, aws_route_table.private_rtbl_1b.id]
  tags = {
    Name = "${var.project_name}_${var.environment_name}_s3_endpoint"
  }
}

output "main_vpc_id" {
  value = aws_vpc.main_vpc.id
}

#output "rds_subnet_ids" {
#  value = tolist([aws_subnet.subnet_1a_datastore.id, aws_subnet.subnet_1b_datastore.id])
#}
#
#output "ecs_subnets" {
#    value = tolist([aws_subnet.subnet_1a_app.id])
#}
#
#output "public_subnets" {
#  value = tolist([aws_subnet.subnet_1a_public.id, aws_subnet.subnet_1b_public.id])
#}
#
#output "serverless_subnets" {
#  value = tolist([aws_subnet.subnet_1a_serverless.id])
#}