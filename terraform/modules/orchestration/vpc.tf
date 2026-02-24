# Optional VPC resources for MWAA
# Enable by setting create_vpc = true
# If create_vpc = false, vpc_id and private_subnet_ids must be provided

# Data source to get available AZs
data "aws_availability_zones" "available" {
  count = var.create_vpc ? 1 : 0
  state = "available"
}

locals {
  # Use created VPC resources or provided values
  vpc_id             = var.create_vpc ? aws_vpc.mwaa[0].id : var.vpc_id
  private_subnet_ids = var.create_vpc ? aws_subnet.private[*].id : var.private_subnet_ids
  
  # VPC CIDR configuration
  vpc_cidr           = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------
resource "aws_vpc" "mwaa" {
  count = var.create_vpc ? 1 : 0

  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-vpc"
  })
}

#------------------------------------------------------------------------------
# Internet Gateway (required for NAT Gateway)
#------------------------------------------------------------------------------
resource "aws_internet_gateway" "mwaa" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.mwaa[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-igw"
  })
}

#------------------------------------------------------------------------------
# Public Subnets (for NAT Gateway)
#------------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = var.create_vpc ? 2 : 0

  vpc_id                  = aws_vpc.mwaa[0].id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-public-${count.index + 1}"
    Type = "public"
  })
}

#------------------------------------------------------------------------------
# Private Subnets (for MWAA)
#------------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = var.create_vpc ? 2 : 0

  vpc_id                  = aws_vpc.mwaa[0].id
  cidr_block              = local.private_subnets[count.index]
  availability_zone       = data.aws_availability_zones.available[0].names[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-private-${count.index + 1}"
    Type = "private"
  })
}

#------------------------------------------------------------------------------
# Elastic IP for NAT Gateway
#------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count = var.create_vpc ? 1 : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-nat-eip"
  })

  depends_on = [aws_internet_gateway.mwaa]
}

#------------------------------------------------------------------------------
# NAT Gateway (required for MWAA outbound internet access)
#------------------------------------------------------------------------------
resource "aws_nat_gateway" "mwaa" {
  count = var.create_vpc ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-nat"
  })

  depends_on = [aws_internet_gateway.mwaa]
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

# Public route table
resource "aws_route_table" "public" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.mwaa[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mwaa[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-public-rt"
  })
}

# Private route table
resource "aws_route_table" "private" {
  count = var.create_vpc ? 1 : 0

  vpc_id = aws_vpc.mwaa[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mwaa[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-mwaa-private-rt"
  })
}

#------------------------------------------------------------------------------
# Route Table Associations
#------------------------------------------------------------------------------

# Public subnet associations
resource "aws_route_table_association" "public" {
  count = var.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private subnet associations
resource "aws_route_table_association" "private" {
  count = var.create_vpc ? 2 : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}
