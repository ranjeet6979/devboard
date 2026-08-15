variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "VPC CIDR block where the bastion host will be deployed."
  type        = string
  default     = "20.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block where the bastion host will be deployed."
  type        = string
  default     = "20.0.1.0/24"
}

variable "name_prefix" {
  description = "Prefix for naming resources."
  type        = string
  default     = "bastion"
}