variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 3
}

variable "instance_type" {
  default = "t3.micro"
}

variable "region" {
    default = "eu-central-1"
}
