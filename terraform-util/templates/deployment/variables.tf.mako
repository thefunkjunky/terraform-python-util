variable "region" {
  description = "AWS Region"
  default = "${region}"
}

variable "environment" {
  description = "Deployment environment name."
  default = "${environment}"
}

variable "vpc_name" { default = "${environment}-vpc" }
variable "vpc_domain" { default = "${vpc_domain_name}" }
variable "vpc_cidr" { default = "${vpc_cidr}" }
# TODO(Garrett): use https://www.terraform.io/docs/language/functions/cidrsubnets.html
variable "vpc_private_cidr" { default = "${vpc_private_cidr}" }
variable "private_subnets" {
  default = {
    % for subnet, config in vpc_private_subnets.items():
    "${environment}_${subnet}" = {
      "cidr" = "${config["cidr"]}",
      "az" = "${region}${config["az_suffix"]}"
    },
    % endfor
  }
}

variable "vpc_public_cidr" { default = "${vpc_public_cidr}" }
variable "public_subnets" {
  default = {
    % for subnet, config in vpc_public_subnets.items():
    "${environment}_${subnet}" = {
      "cidr" = "${config["cidr"]}",
      "az" = "${region}${config["az_suffix"]}"
    },
    % endfor
  }
}
variable "allow_public_ssh" { default = ["0.0.0.0/0"] } # TODO: XXX Dial this down, to be only limited blocks!


# RDS DB Variables
variable "db_name" { default = "${environment}default" }
variable "db_identifier" { default = "${environment}-default" }
variable "db_storage_size" { default = ${db_storage_size} }
variable "db_max_allocated_storage" { default = ${db_max_allocated_storage} }
variable "db_instance_class" { default = "${db_instance_class}" }
variable "db_engine_version" { default = "${db_engine_version}" }
variable "db_publicly_accesible" { default = ${db_publicly_accesible} }
variable "db_skip_final_snapshot" { default = ${db_skip_final_snapshot} }
variable "db_backup_retention_period" { default = ${db_backup_retention_period} }
% if db_password_encrypted:
# aws kms encrypt --output text --query CiphertextBlob --key-id "alias/${environment}-main" --plaintext $(echo -n "[password]" | base64)
variable "db_password_encrypted" { default = "${db_password_encrypted}" }
% endif
