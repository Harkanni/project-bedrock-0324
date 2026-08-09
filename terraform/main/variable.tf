variable "aws_region" {
  description = "AWS region for all Project Bedrock resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the Project Bedrock VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "AZs to spread subnets across (at least 2, per exam requirement)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# One /24 per AZ for public subnets, one /24 per AZ for private subnets.
# Kept simple and non-overlapping — plenty of room for EKS ENIs.
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}
