resource "azurerm_virtual_network" "this" {
  name                = "vnet-agent-runway-dmz"
  location            = var.location
  resource_group_name = azurerm_resource_group.target.name
  address_space       = [var.address_space]
  tags                = local.tags
}

# The instances reach the internet (packages, Key Vault, Storage) through their load balancer's outbound rule. The
# subnet has no default outbound access.
resource "azurerm_subnet" "apps" {
  name                            = "snet-apps"
  resource_group_name             = azurerm_resource_group.target.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [cidrsubnet(var.address_space, 8, 0)]
  default_outbound_access_enabled = false
}

# Only Front Door reaches the apps, on port 80. The default rules still admit the load balancer's health probe and the VNet.
resource "azurerm_network_security_group" "apps" {
  name                = "nsg-agent-runway-dmz-apps"
  location            = var.location
  resource_group_name = azurerm_resource_group.target.name
  tags                = local.tags

  security_rule {
    name                       = "allow-front-door"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "AzureFrontDoor.Backend"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "80"
  }
}

resource "azurerm_subnet_network_security_group_association" "apps" {
  subnet_id                 = azurerm_subnet.apps.id
  network_security_group_id = azurerm_network_security_group.apps.id
}
