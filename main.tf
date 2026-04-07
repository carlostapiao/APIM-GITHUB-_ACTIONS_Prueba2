terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
  # CAMBIO DE KEY: Para forzar un estado nuevo y limpio
  backend "azurerm" {
    resource_group_name  = "rg-apppersonal-tfstate"
    storage_account_name = "stcarlosv3state"
    container_name       = "tfstate-apppersonal"
    key                  = "tfstatev1" 
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# --- 1. Grupo de Recursos (Central US) ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "centralus" 
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

resource "azurerm_subnet" "apim_subnet" {
  name                 = "snet-apim"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# --- 3. Seguridad (NSG para el APIM) ---
resource "azurerm_network_security_group" "apim_nsg" {
  name                = "nsg-apim"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowManagementEndpoint"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc" {
  subnet_id                 = azurerm_subnet.apim_subnet.id
  network_security_group_id = azurerm_network_security_group.apim_nsg.id
}

# --- 4. AKS (Usando familia DC permitida) ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                    = var.aks_name
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  dns_prefix              = "aks-tickets"
  private_cluster_enabled = true 

  default_node_pool {
    name           = "default"
    node_count     = 1
    vm_size        = "Standard_DC2s_v3" 
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity { type = "SystemAssigned" }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16" 
    dns_service_ip    = "10.1.0.10"
  }
}

# --- 5. Roles ---
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- 6. SQL Server y Base de Datos ---
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
  sku_name  = "Basic"
}

resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --- 7. API Management (APIM) con Dependencias Reforzadas ---
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Carlos Tapia"
  publisher_email     = "carlos@example.com"
  sku_name            = "Developer_1"

  virtual_network_type = "External"
  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim_subnet.id
  }

  # ESTO EVITA EL ERROR DE "VNET NOT FOUND":
  depends_on = [
    azurerm_virtual_network.vnet,
    azurerm_subnet.apim_subnet,
    azurerm_subnet_network_security_group_association.assoc
  ]
}

resource "azurerm_api_management_api" "api" {
  name                = "tickets-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "IT Support API"
  path                = "tickets"
  protocols           = ["https"]
}

# --- 8. Container Registry (ACR) ---
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}