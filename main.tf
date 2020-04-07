# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "8afbe872-4126-415f-bbf5-59890b64e029"
    client_id       = "7838c180-37d1-4ef8-a13b-b872a00d5c96"
    client_secret   = var.secret
    tenant_id       = "6e06e42d-6925-47c6-b9e7-9581c7ca302a"
    features {} 
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "backuprg" {
    name     = "{var.prefix}-ResourceGroup"
    location = var.location

    tags = {
        environment = var.environment
    }
}

# Create virtual network
resource "azurerm_virtual_network" "backupNetwork" {
    name                = "var.prefix-Vnet"
    address_space       = ["10.0.0.0/16"]
    location            = var.location
    resource_group_name = azurerm_resource_group.backuprg.name

    tags = {
       environment = var.environment
    }
}

# Create subnet
resource "azurerm_subnet" "backupSubnet" {
    name                 = "var.prefix-Subnet"
    resource_group_name  = azurerm_resource_group.backuprg.name
    virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "backupPublicIP" {
    name                         = "var.prefix-PublicIP"
    location 					 = var.location
    resource_group_name          = azurerm_resource_group.backuprg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = var.environment
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "backupNSG" {
    name                = "var.prefix-NetworkSecurityGroup"
    location            = var.location
    resource_group_name = azurerm_resource_group.backuprg.name
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = var.environment
    }
}

# Create network interface
resource "azurerm_network_interface" "backupNIC" {
    name                      = "var.prefix-NIC"
    location                  = var.location
    resource_group_name       = azurerm_resource_group.backuprg.name
    network_security_group_id = azurerm_network_security_group.myterraformnsg.id

    ip_configuration {
        name                          = "var.prefix-NicConfiguration"
        subnet_id                     = azurerm_subnet.myterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
    }

    tags = {
        environment = var.environment
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.backuprg.name
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "backupStorageAccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.backuprg.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = var.environment
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "backupVM" {
    name                  = var.prefix-Sever
    location              = var.location
    resource_group_name   = azurerm_resource_group.backuprg.name
    network_interface_ids = ["${azurerm_network_interface.myterraformnic.id}"]
    vm_size               = "Standard_B1s"

    storage_os_disk {
        name              = var.prefix-OsDisk
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7-RAW"
        version   = "latest"
    }

    os_profile {
        computer_name  = var.prefix-Sever
        admin_username = "admin"
        admin_password = var.dbpassword
    }

    os_profile_linux_config {
        disable_password_authentication = false
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = var.environment
    }
}
