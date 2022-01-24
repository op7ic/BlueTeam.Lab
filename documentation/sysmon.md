# Sysmon

Sysmon is deployed across every host in the BlueTeam.Lab system and is configured to log data locally so that other collectors can get hold of those data (i.e. Wazuh Agent).

The Ansible deployment task can be found in [ansible/roles/sysmon/tasks/main.yml](../ansible/roles/sysmon/tasks/main.yml).

In order to modify the configuration of Sysmon, please change the following config section in the[domain_setup.yml](../ansible/domain_setup.yml) file.
```
# Sysmon configuration options. This options allows you to set up where to get the Sysmon binary and the configuration files from. 
sysmon:
  installer_url: https://live.sysinternals.com/Sysmon64.exe
  config_url: https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml
```