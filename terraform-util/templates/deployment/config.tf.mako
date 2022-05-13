terraform {
  required_version = "${required_terraform_version}"

  backend "s3" {
    bucket         = "${company}-${realm}-tfstate"
    region         = "${region}"
    key            = "${environment}/root/terraform.tfstate"
    encrypt        = true
    dynamodb_table = "${company}-${realm}-${environment}-root-tfstate"
  }

  required_providers {
    % for provider, values in terraform_providers.items():
    ${provider} = {
      source  = "${values["source"]}"
      version = "${values["version"]}"
    % endfor
    }
  }
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "common" {
  backend = "s3"
  config = {
    bucket = "${company}-${realm}-tfstate"
    key    = "backend/terraform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "zones" {
  backend = "s3"
  config = {
  <%text>bucket = "${local.realm_prefix}-tfstate"</%text>
  key    = "route53-zones/terraform.tfstate"
  region = var.region
  }
}

data "terraform_remote_state" "global_ecr" {
  backend = "s3"
  config = {
  <%text>bucket = "${local.realm_prefix}-tfstate"</%text>
  key    = "global/ecr/terraform.tfstate"
  region = var.region
  }
}
