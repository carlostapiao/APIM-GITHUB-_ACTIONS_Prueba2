terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    helm    = { source = "hashicorp/helm", version = "~> 2.0" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-apppersonal-tfstate"
    storage_account_name = "stcarlosv3state"
    container_name       = "tfstate-apppersonal"
    key                  = "tfstate.v7"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# --- 1. Grupo de Recursos ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# --- 2. Redes (VNET y Subnets) ---
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tickets-lab"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subred para APIM (Solo si usas SKU Developer/Premium para integración total)
resource "azurerm_subnet" "apim_subnet" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- 3. Azure Container Registry ---
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# --- 4. Azure Kubernetes Service (PRIVADO) ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.aks_name
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = "aks-tickets-priv"
  private_cluster_enabled = true # HACE EL CLUSTER PRIVADO

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_DC2s_v3"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id # ASOCIAR A LA RED
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }
}

# --- 5. Unión AKS + ACR ---
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- 6. SQL Server & Database ---
resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.db_password
}

resource "azurerm_mssql_database" "db" {
  name      = "SupportDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0"
}

resource "azurerm_mssql_firewall_rule" "sql_fw" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --- 7. API Management (APIM) ---
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Carlos Tapia"
  publisher_email     = "carlos@example.com"
  
  # Cambiamos a Developer para permitir integración con VNET
  sku_name = "Developer_1" 

  # El APIM tendrá una IP pública para que TÚ accedas, 
  # pero podrá hablar con el AKS por la red interna.
  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  timeouts {
    create = "45m" # APIM en VNET tarda más en desplegar
  }
}

# Configuración de la API en APIM
resource "azurerm_api_management_api" "api" {
  name                = "tickets-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "IT Support API"
  path                = "tickets"
  protocols           = ["http", "https"]
}

# Operaciones de la API (Iguales a tu versión anterior)
resource "azurerm_api_management_api_operation" "get_tickets" {
  operation_id        = "get-tickets-api"
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Get All Tickets"
  method              = "GET"
  url_template        = "/api/tickets"
}

resource "azurerm_api_management_api_operation" "post_ticket" {
  operation_id        = "create-ticket-api"
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Create Ticket"
  method              = "POST"
  url_template        = "/api/tickets"
}

# --- 8. Helm Ingress Nginx (CONFIGURACIÓN INTERNA) ---
provider "helm" {
  kubernetes {
    # Como el cluster es privado, Helm debe correr desde un runner que tenga acceso o via proxy.
    # Para el despliegue inicial, Terraform usará las credenciales de Azure.
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

resource "helm_release" "nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-basic"
  create_namespace = true

  # ESTO ES LO QUE HACE QUE EL INGRESS SEA PRIVADO
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-internal"
    value = "true"
  }
}