variable "subscription_id" {
  description = "ID de la suscripción de Azure"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
  default     = "rg-k8s-lab"
}

variable "aks_name" {
  description = "Nombre del clúster AKS"
  type        = string
  default     = "aks-lab"
}

variable "apim_name" {
  description = "Nombre del servicio APIM"
  type        = string
  default     = "apimcarlos69lmv9"
}

variable "acr_name" {
  description = "Nombre del Azure Container Registry"
  type        = string
  default     = "acrcarlos69lmv8"
}

variable "sql_server_name" {
  description = "Nombre del servidor SQL"
  type        = string
  default     = "sqlserver-carlos-lab"
}

variable "db_password" {
  description = "Password para SQL Server"
  type        = string
  sensitive   = true
}