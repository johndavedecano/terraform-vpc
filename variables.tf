variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  type    = string
  default = "demo_vpc"
}

variable "zones" {
  type    = list(string)
  default = ["a", "b", "c"]
}
