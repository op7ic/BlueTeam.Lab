# Wazuh 

## Wazuh Server
Wazuh server is configured to run on top of Ubuntu and entire configuration is done using headless scripts located in [/ansible/roles/wazuhserver/templates](../ansible/roles/wazuhserver/templates). 

In order to modify the configuration of Wazuh please change the following config section in [domain_setup.yml](../ansible/domain_setup.yml) file.
```
# Setup for Wazuh Server and Agent. Versions will change so you might need to update this URL with time.
wazuh_admin:
  username: blueteam
  password: BlueTeamDetection0%%%
  wazuh_services_password: BlueTeamDetection0%%%
  agent_url: https://packages.wazuh.com/4.x/windows/wazuh-agent-4.2.5-1.msi
```
Please note that the same password, located uner ```wazuh_services_password``` variable will be used for all exposed Wazuh services such as kibana or logstash. ```Username``` and ```Password``` parameters refer to SSH logins for the system so ansible can perform configuration. 


## Wazuh Agent

Wazuh agent is configured to ship logs to authomatically created Wazuh Server so during installation of MSI package, as directed by ```wazuh_admin.agent_url``` variable in [domain_setup.yml](../ansible/domain_setup.yml), IP of the Wazuh Server passed along as one of the parameters. The details of corresponding Ansible task can be found in[/ansible/roles/wazuhagent/tasks/main.yml](../ansible/roles/wazuhagent/tasks/main.yml).