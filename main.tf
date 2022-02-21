##########################################################
# Author      : Jerzy 'Yuri' Kramarz (op7ic)             #
# Version     : 1.0                                      #
# Type        : Terraform                                #
# Description : BlueTeam.Lab. See README.md for details  # 
##########################################################


############################################################
# Provider And Resource Group Definition
############################################################

# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create resource group
# Note that all deployment relies on this resource group so we set manual "depends_on" everywhere
resource "azurerm_resource_group" "resourcegroup" {
  location            = var.region
  name                = var.resource_group
}

############################################################
# Public IP (we use this to configure firewall)
############################################################

# Get Public IP of my current system
data "http" "public_IP" {
  url = "https://ipinfo.io/json"
  request_headers = {
    Accept = "application/json"
  }
}

############################################################
# Local variables used in this template
############################################################
# Define local variables which we will use across number of systems
# Reference variables from main variables.tf file
# If you prefer to add different IP as source, change 'public_ip' variable to match
locals {
  public_ip = jsondecode(data.http.public_IP.body).ip
  config_file = yamldecode(file(var.domain_config_file))
}

############################################################
# Networking Setup - Internal
############################################################

# Define primary network range (10.0.0.0/16)
resource "azurerm_virtual_network" "main" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = var.resource_group
}

# Define LAN for Servers
resource "azurerm_subnet" "servers" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                 = "servers"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.server_subnet_cidr]
}

# Define LAN for Workstations
resource "azurerm_subnet" "workstations" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                 = "workstations"
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.workstations_subnet_cidr]
}

############################################################
# Networking Setup - External
############################################################

resource "azurerm_public_ip" "server" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                    = "${var.prefix}-ingress"
  location                = var.region
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

resource "azurerm_public_ip" "workstation" {
  depends_on = [azurerm_resource_group.resourcegroup]
  count                   = length(local.config_file.workstation_configuration)
  name                    = "${var.prefix}-WKS-${count.index}-ingress"
  location                = var.region
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}

resource "azurerm_public_ip" "wazuh" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                    = "wazuh-ingress"
  location                = var.region
  resource_group_name     = var.resource_group
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
}



############################################################
# Firewall Rule Setup
############################################################

resource "azurerm_network_security_group" "windows" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                = "windows-nsg"
  location            = var.region
  resource_group_name = var.resource_group

  security_rule {
    name                       = "Allow-RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Allow-WinRM"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-WinRM-secure"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SMB"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "wazuh" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                = "wazuh-nsg"
  location            = var.region
  resource_group_name = var.resource_group

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  # Ports defined: https://documentation.wazuh.com/current/getting-started/architecture.html
  security_rule {
    name                       = "Allow-Wazuh-Manager"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "1514-1516"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Wazuh-Elasticsearch"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  
   security_rule {
    name                       = "Allow-Wazuh-API"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "55000"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  
   security_rule {
    name                       = "Allow-Elasticsearch-Cluster"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "9300-9400"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

   security_rule {
    name                       = "Allow-Wazuh-GUI"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Allow-Velociraptor-Client-Connections"
    priority                   = 106
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8000"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Velociraptor-GUI"
    priority                   = 107
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10000"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }
  
  security_rule {
    name                       = "Allow-Fleet-GUI"
    priority                   = 108
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9999"
    source_address_prefix      = "${local.public_ip}/32"
    destination_address_prefix = "*"
  }

}

############################################################
# Wazuh Resource
############################################################

# Create IP address space and interface for Wazuh Manager instance 
resource "azurerm_network_interface" "wazuh" {
    depends_on = [azurerm_resource_group.resourcegroup]
    name                = "wazuh-nic"
    location              = var.region
    resource_group_name   = var.resource_group

    ip_configuration {
    name                          = "static"
    subnet_id                     = azurerm_subnet.servers.id
    private_ip_address_allocation = "Static"
    private_ip_address = cidrhost(var.server_subnet_cidr, 100)
    public_ip_address_id = azurerm_public_ip.wazuh.id
    }
}
# Associate IP and Security Group with our Wazuh Manager instance
resource "azurerm_network_interface_security_group_association" "wazuh" {
    depends_on = [azurerm_resource_group.resourcegroup]
    network_interface_id      = azurerm_network_interface.wazuh.id
    network_security_group_id = azurerm_network_security_group.wazuh.id
}

resource "azurerm_virtual_machine" "wazuh" {
  depends_on = [azurerm_resource_group.resourcegroup]
  name                  = "wazuh"
  location              = var.region
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.wazuh.id]
  vm_size               = var.wazuh_vm_size

  # Apply Tag to our workstations
  tags = {
    kind = "BlueTeam-Wazuh"
  }

  # Delete OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Delete data disks automatically when deleting the VM
  delete_data_disks_on_termination = true
    
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "wazuh-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  
   os_profile {
    computer_name  = "wazuh"
    admin_username = local.config_file.wazuh_admin.username
    admin_password = local.config_file.wazuh_admin.password
  }
   # we use password authentication here for ease of operation
   os_profile_linux_config {
    disable_password_authentication = false
  }
  
}# EOF WAZUH SERVER Provision

# Install Wazuh Server outside of normal installation cycle so we don't have to wait for completion of other tasks.
# We are using null_resource here to do async config of Wazuh server - https://www.terraform.io/language/resources/provisioners/null_resource
resource "null_resource" "wazuh-install" {
    # Ensure Wazuh is not installed until box is up. We will still sleep 120s just to be sure.
    depends_on = [azurerm_resource_group.resourcegroup, azurerm_virtual_machine.wazuh]
    provisioner "local-exec" {
    # Move to working directory
    working_dir = "${path.root}/ansible/"
    # Call out command to setup Wazuh server and get Velociraptor/FleetDM server setup too
    command = "sleep 360; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook wazuh-server.yml -vvv -t wazuhserver,velociraptorserver,fleetserver --extra-vars \"wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
}

############################################################
# DC Server Resource
############################################################

# Create IP address space and interface for our DC server
resource "azurerm_network_interface" "server" {
    depends_on = [azurerm_resource_group.resourcegroup]
    name                = "${var.prefix}-nic"
    location            = var.region
    resource_group_name = var.resource_group

    ip_configuration {
        name                          = "server-static"
        subnet_id                     = azurerm_subnet.servers.id
        private_ip_address_allocation = "Static"
        private_ip_address = cidrhost(var.server_subnet_cidr, 10)
        public_ip_address_id = azurerm_public_ip.server.id
    }
}

# Associate IP and Security Group with our DC
resource "azurerm_network_interface_security_group_association" "dc" {
     depends_on = [azurerm_resource_group.resourcegroup]
     network_interface_id      = azurerm_network_interface.server.id
     network_security_group_id = azurerm_network_security_group.windows.id
}

# Create DC server
resource "azurerm_virtual_machine" "dc" {
        
      depends_on = [azurerm_resource_group.resourcegroup]
      
      name                  = "domain-controller"
      location              = var.region
      resource_group_name   = var.resource_group
      network_interface_ids = [azurerm_network_interface.server.id]
      vm_size               = var.dc_vm_size
       
      # Apply Tag to our DC
      tags = {
       kind = "BlueTeam-DC"
      }
      
      # Delete the OS disk automatically when deleting the VM
      delete_os_disk_on_termination = true

      # Delete data disks automatically when deleting the VM
      delete_data_disks_on_termination = true

      storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = var.dc_os
        sku       = var.dc_SKU
        version   = "latest"
      }
      storage_os_disk {
        name              = "os-disk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
      }
      os_profile {
        computer_name  = local.config_file.dc_name
        admin_username = local.config_file.local_admin_credentials.username
        admin_password = local.config_file.local_admin_credentials.password
      }
      os_profile_windows_config {
          provision_vm_agent = true
          enable_automatic_upgrades = false
          timezone = "Central European Standard Time"
          winrm {
            protocol = "HTTP"
          }
      }

    # TODO
    # Patch DC and restart to make sure all services are setup correctly. Extended wait time in case of slower workstations as various WinRM timeouts were observed here.
    # provisioner "local-exec" {
    # # Move to working directory were we have our setup for DC ansible
    # working_dir = "${path.root}/ansible/"
    # # Call out command to setup dc based on our setup
    # command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t patch '"
    # }
      
    # Provision base domain and DC
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 240; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t base'"
    }

    # Initialize setup of the box, create AD structure, add users etc.
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t initialize --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
    
    # Install various monitoring software
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t monitoring,osqueryagent,sysmon,wazuhagent --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
    
    # Install various monitoring software - continue with installation
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t winlogbeat,velociraptorclient,osqueryagent --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
    
    # Reboot system
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-controller.yml -vvv -t reboot'"
    }

    
}# EOF DC Provision

############################################################
# Workstations Resource
############################################################
# Create IP address space and interface for our workstations 
# Use count as parameter to pass to resources since we are creating multiple systems

resource "azurerm_network_interface" "workstation" {
  depends_on = [azurerm_resource_group.resourcegroup]
  count = length(local.config_file.workstation_configuration)

  name                = "${var.prefix}-WKS-${count.index}-nic"
  location              = var.region
  resource_group_name   = var.resource_group

  ip_configuration {
    name                          = "static"
    subnet_id                     = azurerm_subnet.workstations.id
    private_ip_address_allocation = "Static"
    private_ip_address = cidrhost(var.workstations_subnet_cidr, 10+count.index)
    public_ip_address_id = azurerm_public_ip.workstation[count.index].id
  }
}
# Associate IP and Security Group with our workstations
# Windows firewall setup
resource "azurerm_network_interface_security_group_association" "workstation" {
  depends_on = [azurerm_resource_group.resourcegroup]
  count = length(local.config_file.workstation_configuration)
  network_interface_id      = azurerm_network_interface.workstation[count.index].id
  network_security_group_id = azurerm_network_security_group.windows.id
}

# Create workstations based on our setup
resource "azurerm_virtual_machine" "workstation" {

  count = length(local.config_file.workstation_configuration)
  name                  = local.config_file.workstation_configuration[count.index].name
  location              = var.region
  resource_group_name   = var.resource_group
  network_interface_ids = [azurerm_network_interface.workstation[count.index].id]
  vm_size               = var.workstations_vm_size
  
  # Apply tag to our workstations. We use this to dynamically identify IP addresses.
  tags = {
    kind = "BlueTeam-workstation"
  }

  # Delete OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Delete data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = var.workstation_os
    sku       = var.workstation_SKU
    version   = "latest"
  }
  
  storage_os_disk {
    name              = "wks-${count.index}-os-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  
  os_profile {
    computer_name  = local.config_file.workstation_configuration[count.index].name
    admin_username = local.config_file.local_admin_credentials.username
    admin_password = local.config_file.local_admin_credentials.password
  }
  os_profile_windows_config {
      provision_vm_agent = true
      enable_automatic_upgrades = false
      timezone = "Central European Standard Time"
      winrm {
        protocol = "HTTP"
      }
  }
  
    # TODO
    # Patch system. Extended wait time in case of slower workstations as various WinRM timeouts were observed here.
    # provisioner "local-exec" {
    # # Move to working directory were we have our setup for workstation
    # working_dir = "${path.root}/ansible/"
    # # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    # command = "sleep 100; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t patch'"
    # }
    
    # We need to set provisioner to depend on DC and Wazuh completion. Otherwise it might not setup properly. Boxes can be made and patched before that of course but joing domain requires DC to be alive and present. Same goes for various connectors talking with our Wazuh/Velociraptor servers etc.
    depends_on = [azurerm_resource_group.resourcegroup, azurerm_virtual_machine.dc]  
   
    # Provision base member configuration. Extended wait time in case of slower workstations.
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup
    # We will pass internal IP of the DC via 'extra-vars' to ensure that DNS config is correct
    command = "sleep 300; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t base --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
   
    # Install all monitoring agents
    provisioner "local-exec" {
    # Move to working directory were we have our setup for workstation
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t monitoring,sysmon,wazuhagent --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"'"
    }
    
    # Install all monitoring agents - we split this into 2 tasks.
    provisioner "local-exec" {
    # Move to working directory were we have our setup for workstation
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t winlogbeat,velociraptorclient,osqueryagent --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"'"
    }
    
    # Reboot system. Extended wait time in case of slower workstations as various WinRM timeouts were observed here.
    provisioner "local-exec" {
    # Move to working directory were we have our setup for workstation
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t reboot'"
    }


}# EOF Workstation Setup


############################################################
# Outputs
############################################################

output "printout" {
  value = <<EOF

Network Setup:

Domain Controller = ${azurerm_public_ip.server.ip_address}
%{ for index, ip in azurerm_public_ip.workstation.*.ip_address ~}
Workstation DETECTION${index+1}: ${ip}
%{ endfor ~}
Wazuh Server IP = ${azurerm_public_ip.wazuh.ip_address}
Wazuh Web Interface = https://${azurerm_public_ip.wazuh.ip_address}:443/
Velociraptor Web Inteface: = https://${azurerm_public_ip.wazuh.ip_address}:10000/
FleetDM Web Interface: = https://${azurerm_public_ip.wazuh.ip_address}:9999/

Credentials:

Domain Admin: 
    ${local.config_file.domain_fqdn}\${local.config_file.local_admin_credentials.username} ${local.config_file.local_admin_credentials.password}
Local Admin on Workstations: 
    ${local.config_file.local_admin_credentials.username} ${local.config_file.local_admin_credentials.password}
Wazuh Server SSH Login:
    ${local.config_file.wazuh_admin.username} ${local.config_file.wazuh_admin.password}
Wazuh Logins: 
    wazuh  ${local.config_file.wazuh_admin.wazuh_services_password}
    admin  ${local.config_file.wazuh_admin.wazuh_services_password}
    kibanaserver  ${local.config_file.wazuh_admin.wazuh_services_password}
    kibanaro  ${local.config_file.wazuh_admin.wazuh_services_password}
    logstash  ${local.config_file.wazuh_admin.wazuh_services_password}
    readall  ${local.config_file.wazuh_admin.wazuh_services_password}
    snapshotrestore  ${local.config_file.wazuh_admin.wazuh_services_password}
    wazuh_admin  ${local.config_file.wazuh_admin.wazuh_services_password}
    wazuh_user  ${local.config_file.wazuh_admin.wazuh_services_password}
Velociraptor Web Inteface Login: 
    ${local.config_file.velociraptor_server.username} ${local.config_file.velociraptor_server.password}
FleetDM Web Inteface Login: 
    ${local.config_file.Fleetdm.username} ${local.config_file.Fleetdm.password}

RDP to Domain Controller: 
xfreerdp /v:${azurerm_public_ip.server.ip_address} /u:${local.config_file.domain_fqdn}\\${local.config_file.local_admin_credentials.username} '/p:${local.config_file.local_admin_credentials.password}' +clipboard /cert-ignore

%{ for index, ip in azurerm_public_ip.workstation.*.ip_address }
RDP to Workstation DETECTION${index+1}: ${ip}
xfreerdp /v:${ip} /u:${local.config_file.local_admin_credentials.username} '/p:${local.config_file.local_admin_credentials.password}' +clipboard /cert-ignore
%{ endfor }

EOF
}