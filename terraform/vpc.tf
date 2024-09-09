provider "aws" {
  region = var.region
}

variable "vpc_cidr_block" {}
variable "private_subnet_cidr_blocks" {}
variable "public_subnet_cidr_block" {}
variable "region" {}
//variable "azs" {}

data "aws_availability_zones" "azs" {}

module "myapp-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name            = "myapp-vpc"
  cidr            = var.vpc_cidr_block
  private_subnets = var.private_subnet_cidr_blocks
  public_subnets  = var.public_subnet_cidr_block
  azs             = data.aws_availability_zones.azs.names

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = true
  tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                  = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"         = 1
    "private_subnet"                          = "yes"
  }
}

resource "aws_default_security_group" "myapp-sg" {
  vpc_id = module.myapp-vpc.vpc_id

  //ingress {
   // from_port   = 0
   // to_port     = 0
   // protocol    = "-1"
   // cidr_blocks = ["0.0.0.0/0"]
 // }

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = -1
    protocol    = "icmp"
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    protocol    = "tcp"
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    protocol    = "tcp"
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 3000
    protocol    = "tcp"
    to_port     = 3000
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = -1
    protocol    = "ICMP"
    to_port     = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 8080
    protocol        = "tcp"
    to_port         = 8080
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  }
}
resource "aws_network_acl" "myapp-nacl" {
  vpc_id = module.myapp-vpc.vpc_id
  subnet_ids = concat(
    module.myapp-vpc.public_subnets,
    module.myapp-vpc.private_subnets
  )
  ingress {
    rule_no = 115
    from_port   = 0
    protocol    = "icmp"
    to_port     = 0
    action    = "allow"
    cidr_block = "0.0.0.0/0"
  }
  ingress {
    rule_no = 114
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    action    = "allow"
    cidr_block = "0.0.0.0/0"
  }
  ingress {
    rule_no = 110
    protocol       = "6"
    action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 22
    to_port        = 22
  }

  ingress {
    rule_no = 111
    protocol       = "1"
    action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 0
    to_port        = 65535
  }

  ingress {
    rule_no = 112
    protocol       = "6"  # TCP
    action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 8080
    to_port        = 8080
  }

  ingress {
    rule_no = 113
    protocol       = "6"  # TCP
    action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 3000
    to_port        = 3000
  }

  egress {
    rule_no = 120
    protocol       = "6"  # TCP
    action    = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 0
    to_port        = 65535
  }

  egress {
    rule_no        = 121
    protocol       = "1"
    action         = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 0
    to_port        = 65535
    icmp_type      = -1
    icmp_code      = -1
  }

  tags = {
    "Name" = "myapp-nacl"
  }
}
