##########################################################
# Author      : Jerzy 'Yuri' Kramarz (op7ic)             #
# Version     : 1.0                                      #
# Type        : Terraform                                #
# Description : BlueTeam.Lab. See README.md for details  # 
##########################################################

############################################################
# Defualt config for various settings such as LAN segments, location of domain config file etc.
############################################################

variable "domain_config_file" {
    description = "Path to the primary configuration file for DC"
    default = "ansible/domain_setup.yml"
}

variable "server_subnet_cidr" {
    description = "CIDR to use for the server subnet hosting DC and Wazuh servers"
    default = "10.0.10.0/24"
}

variable "workstations_subnet_cidr" {
    description = "CIDR to use for the Workstations subnet"
    default = "10.0.11.0/24"
}

variable "region" {
    description = "Azure region in which resources should be created. See https://azure.microsoft.com/en-us/global-infrastructure/locations/"
    default = "West Europe"
}

variable "resource_group" {
    description = "Resource group in which resources should be created"
    default = "blueteam-lab"
}

variable "prefix" {
    description = "prefix for dynamic hosts"
    default = "bt-lab"
}

############################################################
# Host Sizing. See https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs for details
############################################################

variable "dc_vm_size" {
    description = "Size of the Domain Controller VM"
    default = "Standard_D2_v2"
}

variable "workstations_vm_size" {
    description = "Size of the workstations VMs"
    default = "Standard_D2_v2"
}

variable "wazuh_vm_size" {
    description = "Size of the Wazuh VM"
    default = "Standard_D3_v2"
}

############################################################
# Host Types to run Windows AD on. Default to Win10 + Win2019 Server
############################################################

variable "dc_os" {
    description = "DC Operating System"
    default = "WindowsServer"
}

variable "dc_SKU" {
    description = "DC SKU"
    default = "2019-Datacenter"
}

variable "workstation_os" {
    description = "Workstations Operating System"
    default = "Windows-10"
}

variable "workstation_SKU" {
    description = "Workstations SKU"
    default = "win10-21h2-ent"
}





