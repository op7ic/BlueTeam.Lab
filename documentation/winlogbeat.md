# WinLogBeat

WinLogBeat (OSS Version) is deployed across every host in the BlueTeam.Lab system and is configured to log data to Elasticsearch instance installed together with Wazuh, irrespective of Wazuh Agent picking up logs for its own monitoring. This was done so that, even when Wazuh indexes and creates its own alerts, any type of custom modelling can still be executed on raw data we pick up from various Windows events and other sources.

Ansible deployment task can be found in [ansible/roles/winlogbeat/tasks/main.yml](../ansible/roles/winlogbeat/main.yml) along with winlogbeat config in [ansible/roles/winlogbeat/templates](../ansible/roles/winlogbeat/templates).

In order to modify the configuration of WinLogBeat, please change the following config section in [domain_setup.yml](../ansible/domain_setup.yml) file.
```
# WinLogBeat download URL
# NOTE: 
# There is a problem with connecting standard WinLogBeat to OSS stack. So OSS version of winlogbeat needs to be used.
# https://discuss.opendistrocommunity.dev/t/problem-with-logstash-and-opendistro-elasticsearch/6265/5
# By default Wazuh comes with Elastic version 7.10 so we use connector with the same version.
winlogbeat:
  windows_download_url: https://artifacts.elastic.co/downloads/beats/winlogbeat/winlogbeat-oss-7.10.2-windows-x86_64.msi
  elastic_user: admin
  elastic_password: BlueTeamDetection0%%%
```

The following configuration is used for WinLogBeat and can be easily modified by changing the file located in the [templates directory](../ansible/roles/winlogbeat/templates/):

```
winlogbeat.event_logs:
  - name: Security
  - name: Microsoft-Windows-Sysmon/Operational
  - name: Application
  - name: Microsoft-windows-PowerShell/Operational
    event_id: 4103, 4104
  - name: Windows PowerShell
    event_id: 400,600
    ignore_older: 30m
  - name: Microsoft-Windows-WMI-Activity/Operational
    event_id: 5857,5858,5859,5860,5861

output.elasticsearch:
  hosts:
  - https://{{ wazuh_server_ip }}:9200
  index: "winlogbeat-%{+yyyy.MM.dd}"
  username: "{{ winlogbeat_elastic_user }}"
  password: "{{ winlogbeat_elastic_password }}"
  ssl.verification_mode: none
  
setup.template.name: "winlogbeat"
setup.template.pattern: "winlogbeat-*"
setup.kibana.ssl.verification_mode: none
```