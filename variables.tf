variable "aws_region" {
  description = "default region"
  type        = string
  default     = "eu-north-1"
}

variable "aws_availability_zone" {
  description = "A list of availability zones within the region"
  type        = list(string)
  default     = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
}

variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}

variable "allowed_ssh_ip" {
  description = "for security groups - A list of ip addresses that can access the ec2 instance through ssh connection"
  type        = list(string)
}

variable "allowed_http_ip" {
  description = "for security groups - A list of ip addresses that can access the ec2 instance through http connections"
  type        = list(string)
}

variable "allowed_outbound_ip" {
  description = "for security groups - A list of ip addresses that can make outbound connections/request from the ec2 instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_key_path" {
  description = "path to ssh public key for ec2 instance"
  type        = string
}