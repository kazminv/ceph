//variable "vpc_subnets" {}
//variable "fargate_private_subnet" {}

terraform {
  required_version = ">= 0.12"
  backend "s3" {
    bucket = "first-java-project"
    key = "myapp/state.tfstate"
    region = "us-east-1"

  }
}
//EKS
module "myapp-eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.11.1"
  cluster_name    = "myapp-eks-cluster"
  cluster_version = "1.30"

  subnet_ids = concat(module.myapp-vpc.private_subnets, module.myapp-vpc.public_subnets)
  vpc_id     = module.myapp-vpc.vpc_id
  cluster_security_group_id = aws_default_security_group.myapp-sg.id

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access  = true
  cluster_addons = {
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }
  tags = {
    environment = "development"
    application = "myapp"
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  }
  eks_managed_node_groups = {
    myapp-node-group = {
      desired_size = 3
      max_size     = 3
      min_size     = 1
      cluster_primary_security_group_id = aws_default_security_group.myapp-sg.id
      vpc_security_group_ids = [aws_default_security_group.myapp-sg.id]
      source_security_group_ids = [aws_default_security_group.myapp-sg.id]
      ec2_ssh_key = "AWS-servers-key"
      subnet_ids = module.myapp-vpc.private_subnets


      instance_types = ["t2.medium"]
      key_name = "AWS-servers-key"
      additional_tags = {
        application = "myapp"
        Terraform   = "true"
      }
    }
  }

}
data "aws_eks_cluster" "myapp-cluster" {
  name = module.myapp-eks.cluster_name
  depends_on = [module.myapp-eks]
}
data "aws_eks_cluster_auth" "myapp-cluster-auth" {
  name = module.myapp-eks.cluster_name
  depends_on = [module.myapp-eks]
}
provider "kubernetes" {
  load_config_file       = "false" //не качать дефолт файл для аутент
  host                   = data.aws_eks_cluster.myapp-cluster.endpoint
  token                  = data.aws_eks_cluster_auth.myapp-cluster-auth.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.myapp-cluster.certificate_authority.0.data)
}

// Создание EC2 инстанса для Bastion
resource "aws_instance" "bastion" {
  ami                    = "ami-0ae8f15ae66fe8cda"
  instance_type          = "t2.micro"
  key_name               = "AWS-servers-key"
  subnet_id              = element(module.myapp-vpc.public_subnets, 0) // первая публичная подсеть
  security_groups = [aws_default_security_group.myapp-sg.id]
  associate_public_ip_address = true

  tags = {
    Name        = "Bastion"
    Environment = "development"
  }
}