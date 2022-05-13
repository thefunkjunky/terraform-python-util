terraform {
  required_version = "${required_terraform_version}"

  backend "s3" {
    bucket         = "${company}-${realm}-tfstate"
    key            = "backend/terraform.tfstate"
    region         = "${region}"
    encrypt        = true
    dynamodb_table = "${company}-${realm}-backend-tfstate"
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
