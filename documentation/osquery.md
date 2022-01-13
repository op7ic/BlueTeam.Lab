# OSQuery and FleetDM

FleetDM-managed instance of OSQuery is deployed across every host in BlueTeam.Lab system and is configured to log data to Fleet Manager installed on the same server where Wazuh instance is.

Ansible OSQuery deployment task can be found in [ansible/roles/osqueryagent/tasks/main.yml](../ansible/roles/osqueryagent/tasks/main.yml) and corresponding FleetDM in [../ansible/roles/fleetserver/tasks/main.yml](/ansible/roles/fleetserver/tasks/main.yml).

In order to modify the configuration of OSQuery and Fleet please change the following config section in [domain_setup.yml](ansible/domain_setup.yml) file.
```
# FleetDM Fleet Setup
Fleetdm:
  enroll_secret: 7548392034598765483902313249182541924120598152194
  server_download_url: https://github.com/fleetdm/fleet/releases/download/fleet-v4.8.0/fleet_v4.8.0_linux.tar.gz
  client_download_url: https://github.com/fleetdm/fleet/releases/download/v0.0.5/orbit_0.0.5_windows.zip
  server_install_folder: /opt/fleetdm
  redis_address: 127.0.0.1:6379
  mysql:
    address: 127.0.0.1:3306
    database: fleetdm
    username: blueteam
    password: BlueTeamDetection0%%%
  webserver:
    port: 9999
    listener_address: 0.0.0.0
    tls: true
  osquery:
    result_log_file: /opt/fleetdm/osquery_result.log
    status_log_file: /opt/fleetdm/osquery_status.log
  logging:
    json: true
    
# OSQuery download URL. Versions will change so you might need to update this URL with time.
osquery_download:
  windows_url: https://pkg.osquery.io/windows/osquery-5.1.0.msi
  debian_url: https://pkg.osquery.io/deb/osquery_5.1.0-1.linux_amd64.deb
```

Please note that Ansible deployment task, [ansible/roles/osqueryagent/tasks/main.yml](../ansible/roles/osqueryagent/tasks/main.yml), pulls a number of configuration files from [Palantir configuration GitHub repo](https://github.com/palantir/osquery-configuration).

## How To Change SSL cetificate

By default pre-generated and self-signed certificates are copied in for clinet-server setup between OSQuery and Fleetdm. In order to change certificates please use following command to generate new ones and place in templates directory for OSQuery [ansible/roles/osqueryagent/templates/](../ansible/roles/osqueryagent/templates/) and Fleetdm server ([ansible/roles/fleetserver/templates/](../ansible/roles/fleetserver/templates/).

```
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/ssl.key -out /tmp/ssl.crt -subj /CN=[IP of Wazuh SERVER] -batch
# for example: openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/ssl.key -out /tmp/ssl.crt -subj /CN=10.0.10.100 -batch
```

NOTE: In order to pass certificate validation in OSQuery/FleetDM setup, CN needs to have either FQDN or IP of the FleetDM server.