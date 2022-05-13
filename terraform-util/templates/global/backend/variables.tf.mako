variable "region" {
  description = "AWS Region"
  default = "${region}"
}

variable "company" {
  description = "Deployment company name."
  default = "${company}"
}

variable "realm" {
  description = "Deployment AWS realm name."
  default = "${realm}"
}
