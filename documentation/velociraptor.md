# Velociraptor

## Velociraptor server

Velociraptor server is configured to run on top of Ubuntu (Wazuh Server) and entire configuration is done using pre-generated configuration file located in [templates folder](../ansible/roles/velociraptorserver/templates). If you would like to modify this setup please change [Ansible task](../ansible/roles/velociraptorserver/tasks/main.yml).

In order to modify the configuration of Velociraptor Server please change the following config section in [domain_setup.yml](../ansible/domain_setup.yml) file.
```
# Velociraptor server/client binary location. Versions will change so you might need to update this URL with time.
velociraptor_server:
  server_download: https://github.com/Velocidex/velociraptor/releases/download/v0.6.3-rc1/velociraptor-v0.6.3-rc1-linux-amd64
  client_download: https://github.com/Velocidex/velociraptor/releases/download/v0.6.2/velociraptor-v0.6.2-windows-amd64.msi
  username: blueteam
  password: BlueTeamDetection0%%%
```

```Username``` and ```Password``` parameters refer to web login for Velociraptor Server console and corresponds to installation scripts which can be found in [templates folder](../ansible/roles/velociraptorserver/templates). 


## Velociraptor Agent

As Velociraptor agent configuration, encryption keys and other details are derived from server setup, pre-configured settings are available in [templates folder](../ansible/roles/velociraptorclient/templates). If you would like to modify this setup please change [Ansible task](../ansible/roles/velociraptorclient/tasks/main.yml).


## Changing Agent and Server Settings

Please follow official guidance for [Agent](https://docs.velociraptor.app/docs/deployment/clients/) and [Server](https://docs.velociraptor.app/docs/deployment/self-signed/) setup and ensure that where needed, ```{{ wazuh_server_ip }}``` variable is set appropriately in both client and server config files so that automatic setup can take care of connecting clients and servers without need for manual intervention.

For Server, the following variables need to be set:
```
Client.server_url: - https://{{ wazuh_server_ip }}:8000/
API.hostname: {{ wazuh_server_ip }}
GUI.bind_address: 0.0.0.0
Frontend.hostname: {{ wazuh_server_ip }}
```

For Client, the following variable need to be set:
```
Client.server_url: - https://{{ wazuh_server_ip }}:8000/
```
