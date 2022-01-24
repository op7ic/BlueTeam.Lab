# Domain Members

# Setup

Windows AD domain members (2x Windows 10 systems) are set to join the AD structure after both DC and Wazuh server are created. This is done via the 'depends_on' function seen in [main.tf](../main.tf) file (also shown below). The domain member provisioner takes advantage of both [role file](../ansible/roles/domain-member/tasks/main.yml) and tags to install software in a specific order.

The following Terraform provisioning process in [main.tf](../main.tf) is configured for each workstation:

```
    # We need to set provisioner to depend on he DC and Wazuh completion. Otherwise it might not setup properly. Boxes can be made and patched before that of course but joining a domain requires the DC to be alive and present. The same goes for various connectors talking with our Wazuh/Velociraptor servers etc.
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
    
    # Reboot system. Extended wait times in case of slower workstations as various WinRM timeouts were observed here.
    provisioner "local-exec" {
    # Move to working directory were we have our setup for workstation
    working_dir = "${path.root}/ansible/"
    # Call out command to setup workstation based on our setup along with all agents and pass specific variables to various handlers.
    command = "sleep 120; /bin/bash -c 'ANSIBLE_CONFIG=${path.root}/ansible.cfg ansible-playbook domain-member.yml -vvv -t reboot'"
    }
```

## How to add more domain members ?

Since Terraform provisioner looks into [domain config file](../ansible/domain_setup.yml), adding new domain members is as easy as adding new sections to the following part of the configuration:

```
# Workstations to create and to domain-join. Users john, karen, florence are local admins on these systems.
workstation_configuration:
- name: DETECTION1
  local_admins: [john, karen, florence]
- name: DETECTION2
  local_admins: [john, karen, florence]
```

For example, if you would like to have 4 workstations, the [domain config file](../ansible/domain_setup.yml) would need to be modified to look like this:

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

Simply delete lines from the ```workstation_configuration``` section of [domain config file](../ansible/domain_setup.yml) file. For example, if you would like to have 1 workstation, just change the config file to look as follows:

```
# Workstations to create and to domain-join. Users john, karen, florence are local admins on these systems.
workstation_configuration:
- name: DETECTION1
  local_admins: [john, karen, florence]
```

## Slow setup for workstations

During my tests I noticed that Azure appears to slow down the boot time for some of the systems over time. Simply put, initially Azure creation is very quick but with the subsequent rebuilding process it appears to slow down. To counter this effect, and reduce the potential for any timeouts, when the Windows system is being rebooted, the following timeout parameters are added to ensure that even if we have a slow start, the Ansible playbooks won't quit the setup process:

```
    # Sleep for 5 minutes. This is to give time for the workstation to set itself properly.
    # In my experiments, WinRM was timing out a lot with 'connection refused' error here otherwise.
    - name: Sleep
      pause:
        minutes: 5
      tags: base  
 
    # We add extra time here to wait for the reboot in case of slower workstations. Our users can choose any rig they want, including 1GB RAM after all.
    - name: Reboot machine if it has just joined the domain
      win_reboot:
        reboot_timeout: 3600
        post_reboot_delay: 180
      when: domain_state.reboot_required
      tags: base
```

If you would like to change this, please edit ansible setup file [ansible/roles/domain-member/tasks/main.yml](../ansible/roles/domain-member/tasks/main.yml).
