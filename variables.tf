variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "backup"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
}

variable "environment" {
  description = "environment tag."
}

variable "secret" {
  description = "secret AD password."
}

variable "dbpassword" {
  description = "database password."
}
