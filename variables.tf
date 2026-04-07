variable "subscription_id" {
  default = "e690edad-0257-4dec-b4c9-08e163433edb"
}

variable "location" {
  default = "centralus"
}

variable "resource_group_name" {
  default = "rg-k8s-lab"
}

variable "acr_name" {
  default = "acrcarlos69lm"
}

variable "aks_name" {
  default = "aks-lab"
}

variable "apim_name" {
  default = "apimcarlos69lmv8" 
}

variable "sql_server_name" {
  default = "sql-server-tickets-carlos"
}

variable "db_password" {
  type      = string
  sensitive = true
}