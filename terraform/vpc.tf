# VPC Configuration
# Creates VPC, subnets, internet gateway, and NAT gateway

# ============================================
# VPC
# ============================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-vpc"
    }
  )
}

# ============================================
# Internet Gateway
# ============================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-igw"
    }
  )
}

# ============================================
# Public Subnets
# ============================================

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-public-subnet-${count.index + 1}"
      Type = "Public"
    }
  )
}

# ============================================
# Private Subnets
# ============================================

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-private-subnet-${count.index + 1}"
      Type = "Private"
    }
  )
}

# ============================================
# Database Subnets
# ============================================

resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.database_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-database-subnet-${count.index + 1}"
      Type = "Database"
    }
  )
}

# ============================================
# Elastic IP for NAT Gateway
# ============================================

resource "aws_eip" "nat" {
  domain = "vpc"
  
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-nat-eip"
    }
  )
}

# ============================================
# NAT Gateway
# ============================================

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  
  depends_on = [aws_internet_gateway.main]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-nat-gateway"
    }
  )
}

# ============================================
# Route Table - Public
# ============================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-public-rt"
    }
  )
}

# ============================================
# Route Table Association - Public Subnets
# ============================================

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ============================================
# Route Table - Private
# ============================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-private-rt"
    }
  )
}

# ============================================
# Route Table Association - Private Subnets
# ============================================

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================
# Route Table - Database
# ============================================

resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-database-rt"
    }
  )
}

# ============================================
# Route Table Association - Database Subnets
# ============================================

resource "aws_route_table_association" "database" {
  count = length(aws_subnet.database)
  
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# ============================================
# VPC Endpoints (for cost optimization)
# ============================================

# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  
  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.database.id
  ]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-s3-endpoint"
    }
  )
}

# Glue VPC Endpoint
resource "aws_vpc_endpoint" "glue" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-glue-endpoint"
    }
  )
}

# ============================================
# Security Groups
# ============================================

# VPC Endpoints Security Group
resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.resource_prefix}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-vpc-endpoints-sg"
    }
  )
}
