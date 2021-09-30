terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "jmch1692"
    workspaces {
        prefix = "quickstart-"
    }
  }
}

module "vpc" {
    source              = "./terraform/vpc"
    environment_name    = var.environment_name
    project_name        = var.project_name
    cidr_block_map      = var.cidr_block_map
}