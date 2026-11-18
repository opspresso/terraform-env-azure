resource "azurerm_virtual_network" "this" {
  name                = "vnet-forge-desktop-dmz"
  location            = var.location
  resource_group_name = azurerm_resource_group.base.name
  address_space       = [var.address_space]
  tags                = local.tags
}

# The desktops have no public IP. AVD connects to them by reverse connect, and they reach the internet (AVD, Entra,
# Windows Update, the Forge desktop gateway, Git and package hosts) only through the NAT Gateway.
resource "azurerm_subnet" "desktops" {
  name                            = "desktops"
  resource_group_name             = azurerm_resource_group.base.name
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = [cidrsubnet(var.address_space, 8, 0)]
  default_outbound_access_enabled = false
}

# Nothing reaches a desktop, not even another desktop of the VNet: the rule overrides the default AllowVnetInBound and
# AllowAzureLoadBalancerInBound rules. Outbound keeps the default rules.
resource "azurerm_network_security_group" "desktops" {
  name                = "nsg-forge-desktop-dmz-desktops"
  location            = var.location
  resource_group_name = azurerm_resource_group.base.name
  tags                = local.tags

  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "desktops" {
  subnet_id                 = azurerm_subnet.desktops.id
  network_security_group_id = azurerm_network_security_group.desktops.id
}

# The egress IP of every desktop. The Forge desktop gateway accepts requests only from it (the pool's egressIps).
resource "azurerm_public_ip" "egress" {
  name                = "pip-forge-desktop-dmz-egress"
  location            = var.location
  resource_group_name = azurerm_resource_group.base.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "this" {
  name                    = "ng-forge-desktop-dmz"
  location                = var.location
  resource_group_name     = azurerm_resource_group.base.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  tags                    = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "egress" {
  nat_gateway_id       = azurerm_nat_gateway.this.id
  public_ip_address_id = azurerm_public_ip.egress.id
}

resource "azurerm_subnet_nat_gateway_association" "desktops" {
  subnet_id      = azurerm_subnet.desktops.id
  nat_gateway_id = azurerm_nat_gateway.this.id
}
