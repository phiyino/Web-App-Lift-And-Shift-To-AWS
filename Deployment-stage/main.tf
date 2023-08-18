# configure aws provider
provider "aws" {
    region = var.region
}

# Store terraform state to S3
terraform {
  backend "s3" {
    bucket         = "wls-tfstate"
    region         = "us-east-1"
    key            = "terraform.tfstate"
  }
}

# create vpc
module "vpc" {
    source = "../modules/vpc"
    region                  = var.region
    project_name            = var.project_name
    vpc_cidr                = var.vpc_cidr
    public_subnet_cidr  = var.public_subnet_cidr
    public_subnet2_cidr = var.public_subnet2_cidr
    private_subnet_cidr = var.private_subnet_cidr 
}

#create security group
module "Security_Group" {
    source = "../Modules/Security_Group"
    project_name = module.vpc.project_name
    vpc_id = module.vpc.vpc_id
}

#create ec2 instances
module "EC2Instances" {
    source = "../Modules/EC2Instances"
    ami_id = var.ami_id
    project_name = module.vpc.project_name
    public_subnet_id = module.vpc.public_subnet_id
    private_subnet_id = module.vpc.private_subnet_id
    instance_type = var.instance_type
    key_pair = var.key_pair
    tomcat_sg_id = module.Security_Group.tomcat_sg_id
    backend_sg_id = module.Security_Group.backend_sg_id
    ami_ubuntu = var.ami_ubuntu 
}

#create private hosted zone
module "Route53" {
    source = "../Modules/Route53"
    vpc_id = module.vpc.vpc_id
    db01_server = module.EC2Instances.db01_server
    mc01_server = module.EC2Instances.mc01_server
    rmq01_server = module.EC2Instances.rmq01_server
}

# create s3
module "S3" {
    source = "../Modules/S3"
}


# create application load balancer
module "ALB" {
    source = "../Modules/ALB"
    vpc_id = module.vpc.vpc_id
    alb_sg_id = module.Security_Group.alb_sg_id
   public_subnet_id = module.vpc.public_subnet_id
   public_subnet2_id = module.vpc.public_subnet2_id
   project_name = module.vpc.project_name
   app01_server = module.EC2Instances.app01_server
} 