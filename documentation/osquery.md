Standalone OSQuery is deployed across every host in BlueTeam.Lab system and is configured to log data locally so that other collectors can get hold of that data (i.e. Wazuh Agent).

Ansible deployment task can be found in [ansible/roles/osqueryagent/tasks/main.yml](../ansible/roles/osqueryagent/tasks/main.yml) and corresponding osquery config in [ansible/roles/osqueryagent/templates/osquery.conf](../ansible/roles/osqueryagent/templates/osquery.conf).

In order to modify the configuration of OSQuery please change the following config section in [domain_setup.yml](ansible/domain_setup.yml) file.
```
# OSQuery download URL. Versions will change so you might need to update this URL with time.
osquery_download:
  windows_url: https://pkg.osquery.io/windows/osquery-5.1.0.msi
  debian_url: https://pkg.osquery.io/deb/osquery_5.1.0-1.linux_amd64.deb
```

Please note that Ansible deployment task, [ansible/roles/osqueryagent/tasks/main.yml](../ansible/roles/osqueryagent/tasks/main.yml), pulls a number of configuration files from [Palantir configuration GitHub repo](https://github.com/palantir/osquery-configuration).