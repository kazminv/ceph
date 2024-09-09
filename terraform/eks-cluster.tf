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

resource "aws_launch_template" "additional_EBS" {

  name = "my_template"
  key_name = "AWS-servers-key" # попытка добавить SG кластера сюда ниже
  vpc_security_group_ids = [aws_default_security_group.myapp-sg.id]
  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size = 8
      volume_type = "gp3"
    }
  }
  block_device_mappings {
    device_name = "/dev/sdg"
    ebs {
      volume_size = 4
      volume_type = "gp3"
    }
  }
  lifecycle {
    create_before_destroy = true
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
      create_launch_template = false
      #launch_template_name = aws_launch_template.additional_EBS.name
      remote_access = {
       ec2_ssh_key = "AWS-servers-key"
      }
      instance_types = ["t2.medium"]
      key_name = "AWS-servers-key"

      use_custom_launch_template = false
      //launch_template_id = aws_launch_template.additional_EBS.id
      // launch_template_version = "$Latest"
      additional_tags = {
        application = "myapp"
        Terraform   = "true"
      }
    }
  }
}

//add new ROLE
/*
resource "aws_iam_role" "additional_eks_role" {
  name = "additional_eks_role_for_sa_tf"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::590183654020:oidc-provider/${module.myapp-eks.oidc_provider_arn}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.myapp-eks.oidc_provider_arn}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

 */
  //create a new policy
resource "aws_iam_policy" "additional_policy" {
  name        = "additional_eks_policy_tf"
  description = "additional permissions for EKS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "ec2:DescribeInstances"
        ],
        Resource = "*"
      }
    ]
  })
}
// attach policy к ROLE
/*
resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.additional_eks_role.name
  policy_arn = aws_iam_policy.additional_policy.arn
}

 */
//create a service account and attach to a new ROLE
//resource "kubernetes_service_account" "ebs_csi_controller_sa" {
  //metadata {
    //name      = "ebs-csi-controller-sa"
    //namespace = "kube-system"
    //annotations = {
      //"eks.amazonaws.com/role-arn" = aws_iam_role.additional_eks_role.arn
    //}
  //}
//}

output "cluster_security_group_id" {
  value = module.myapp-eks.cluster_security_group_id
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
 // load_config_file       = "false" //не качать дефолт файл для аутент
  host                   = data.aws_eks_cluster.myapp-cluster.endpoint
  token                  = data.aws_eks_cluster_auth.myapp-cluster-auth.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.myapp-cluster.certificate_authority.0.data)
}

// EC2 Bastion
#resource "aws_instance" "bastion" {
  #ami                    = "ami-0ae8f15ae66fe8cda"
  #instance_type          = "t2.micro"
  #key_name               = "AWS-servers-key"
  #subnet_id              = element(module.myapp-vpc.public_subnets, 0)
  #security_groups = [aws_default_security_group.myapp-sg.id]
  #associate_public_ip_address = true

  #tags = {
    #Name        = "Bastion"
    #Environment = "development"
  #}
#}