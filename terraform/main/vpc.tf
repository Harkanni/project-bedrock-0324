locals {
  cluster_name = "project-bedrock-cluster"
}

# --- VPC ---------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "project-bedrock-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "project-bedrock-igw"
  }
}

# --- Public subnets (one per AZ) ----------------------------------------
# Host the NAT Gateway and, later, the ALB.

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "project-bedrock-public-${var.availability_zones[count.index]}"
    # Required so EKS / the AWS Load Balancer Controller can auto-discover
    # this subnet as a candidate for internet-facing load balancers.
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# --- Private subnets (one per AZ) ---------------------------------------
# Host EKS worker nodes, RDS instances, and internal-only resources.

resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "project-bedrock-private-${var.availability_zones[count.index]}"
    # Required so EKS / the AWS Load Balancer Controller can auto-discover
    # this subnet for internal load balancers and EC2 auto-discovery.
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

# --- Single NAT Gateway (cost guardrail per exam spec) ------------------
# One NAT Gateway total, placed in the first public subnet, shared by
# both private subnets' route tables. Cheaper than one-per-AZ; the exam
# explicitly calls this out as the preferred setup unless there's a
# specific reason to do otherwise.

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "project-bedrock-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "project-bedrock-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# --- Route tables ---------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "project-bedrock-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Single private route table — both private subnets share the one
# NAT Gateway for outbound internet access (e.g. pulling container images).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "project-bedrock-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
