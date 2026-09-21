data "azurerm_resource_group" "primary" {
  name = "rg-primary"
}

data "azurerm_subnet" "app" {
  name                 = "snet-app"
  virtual_network_name = "vnet-primary"
  resource_group_name  = data.azurerm_resource_group.primary.name
}

resource "azurerm_network_interface" "vms" {
  count = var.vm_count

  name                = "nic-${var.name_prefix}-${count.index + 1}"
  location            = data.azurerm_resource_group.primary.location
  resource_group_name = data.azurerm_resource_group.primary.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "vms" {
  count = var.vm_count

  name                            = "vm-${var.name_prefix}-${count.index + 1}"
  resource_group_name             = data.azurerm_resource_group.primary.name
  location                        = data.azurerm_resource_group.primary.location
  size                            = var.vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.vms[count.index].id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

output "vm_private_ips" {
  value = azurerm_network_interface.vms[*].private_ip_address
}
