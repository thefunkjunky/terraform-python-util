terraform {
  required_version = "${required_terraform_version}"

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
