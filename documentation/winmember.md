# Domain Members

# Setup

Windows AD domain members (2x Windows 10 systems) are set to be join AD structure after both DC and Wazuh server are created. This is done via 'depends_on' function seen in [main.tf](../main.tf) file (also shown below). Domain member provisioner takes advantage of both [role file](../ansible/roles/domain-member/tasks/main.yml) and tags to install software in specific order.

The following Terraform provisioning process in [main.tf](../main.tf) is configured for each workstation:

```
    # We need to set provisioner to depend on DC and Wazuh completion. Otherwise it might not setup properly. Boxes can be made before that of course but joing domain requires DC to be alive and present. 
    # Same goes for various connectors talking with our Wazuh/Velociraptor servers etc.
    depends_on = [azurerm_resource_group.resourcegroup, azurerm_virtual_machine.dc, azurerm_virtual_machine.wazuh]      
   
    # Provision base member configuration 
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup
    # We will pass internal IP of the DC via 'extra-vars' to ensure that DNS config is correct
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg AZURE_AD_USER=${local.config_file.local_admin_credentials.username} AZURE_PASSWORD=${local.config_file.local_admin_credentials.password} ansible-playbook domain-member.yml -v -t common,base --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }

    # Add monitoring/auditing and sysmon to the box
    provisioner "local-exec" {
    # Move to working directory were we have our setup for workstation
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    command = "/bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg AZURE_AD_USER=${local.config_file.local_admin_credentials.username} AZURE_PASSWORD=${local.config_file.local_admin_credentials.password} ansible-playbook domain-member.yml -v -t common,monitoring,osqueryagent,sysmon,wazuhagent,winlogbeat --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
```

Outside of primary Terraform provisioning process in [main.tf](../main.tf) we have patching process:

```
############################################################
# Windows Patching Process
############################################################
# Patch systems outside of main provisioning so we can carry on with setup before that. 

resource "null_resource" "patch-workstation" {
    # Ensure this isn't triggered until workstations are created
    depends_on = [azurerm_resource_group.resourcegroup, azurerm_virtual_machine.workstation]
    provisioner "local-exec" {
    # Move to working directory were we have our setup for DC ansible
    working_dir = "${path.root}/ansible/"
    # Call out command to setup dc based on our setup
    command = "sleep 60; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg AZURE_AD_USER=${local.config_file.local_admin_credentials.username} AZURE_PASSWORD=${local.config_file.local_admin_credentials.password} ansible-playbook domain-member.yml -v -t common,patch --extra-vars \"dc_internal_ip=${azurerm_network_interface.server.private_ip_address} wazuh_server_ip=${azurerm_network_interface.wazuh.private_ip_address}\"' "
    }
}
```

## How to add more domain members ?

Since Terraform provisioner looks into [domain config file](../ansible/domain_setup.yml) adding new domain members is as easy as adding new sections to the following part of the configuration:

```
# Workstations to create and to domain-join. Users john, karen, florence are local admins on these systems.
workstation_configuration:
- name: DETECTION1
  local_admins: [john, karen, florence]
- name: DETECTION2
  local_admins: [john, karen, florence]
```

For example, if you would like to have 4 workstations, [domain config file](../ansible/domain_setup.yml) would need to be modified to look like this:

```
# Workstations to create and to domain-join. Users john, karen, florence are local admins on these systems.
workstation_configuration:
- name: DETECTION1
  local_admins: [john, karen, florence]
- name: DETECTION2
  local_admins: [john, karen, florence]
- name: DETECTION3
  local_admins: [john, karen, florence]
- name: DETECTION4
  local_admins: [john, karen, florence]
```

## How to remove domain members ?

Simply delete lines from ```workstation_configuration``` section of [domain config file](../ansible/domain_setup.yml) file. For example, if you would like to have 1 workstation, just change the config file to look as follows:

```
# Workstations to create and to domain-join. Users john, karen, florence are local admins on these systems.
workstation_configuration:
- name: DETECTION1
  local_admins: [john, karen, florence]
```

## Slow setup for workstations

During my tests I noticed that Azure appears to slow down boot time for some of the systems over time. Simply put, initially Azure creation is very quick but with subsequent rebuilding process it appears to slow down. To counter this effect, and reduce potential for any timeouts, when windows system is rebooted, the following timeout parameters are added to ensure that even if we have slow start, ansible playbooks won't quit the setup process:

```
  win_reboot:
    reboot_timeout: 3600
    post_reboot_delay: 120
```

If you would like to change this, please edit ansible setup file [ansible/roles/domain-member/tasks/main.yml](../ansible/roles/domain-member/tasks/main.yml).