Install Newrelic

Newrelic Dashboars -> +Add Data -> Guided install -> Installation plan

Newrelic can monitor system and application logs throuth its agent:
System and app logs - newrelic agent - Newrelic
But we use Fluent-bit for advanced managing application logs and newrelic agent for :
App logs -> Fleunt-bit - Newrelic



<details>
  <summary>C:\ProgramData\New Relic\.NET Agent\newrelic.config</summary>
  ```
<?xml version="1.0"?>
<!-- Copyright (c) 2008-2020 New Relic, Inc.  All rights reserved. -->
<!-- For more information see: https://docs.newrelic.com/docs/agents/net-agent/configuration/net-agent-configuration/ -->
<configuration xmlns="urn:newrelic-config" agentEnabled="true">
  <service licenseKey="NEW_RELIC_LICENSE_KEY" />
  <application />
  <log level="info" />
  <allowAllHeaders enabled="true" />
  <attributes enabled="true">
    <exclude>request.headers.cookie</exclude>
    <exclude>request.headers.authorization</exclude>
    <exclude>request.headers.proxy-authorization</exclude>
    <exclude>request.headers.x-*</exclude>
    <include>request.headers.*</include>
  </attributes>
  <transactionTracer enabled="true" transactionThreshold="apdex_f" stackTraceThreshold="500" recordSql="obfuscated" explainEnabled="false" explainThreshold="500" />
  <distributedTracing enabled="true" />
  <errorCollector enabled="true">
    <!-- <ignoreClasses> -->
    <!-- <errorClass>System.IO.FileNotFoundException</errorClass> -->
    <!-- <errorClass>System.Threading.ThreadAbortException</errorClass> -->
    <!-- </ignoreClasses> -->
    <ignoreStatusCodes>
      <code>401</code>
      <code>404</code>
    </ignoreStatusCodes>
  </errorCollector>
  <browserMonitoring autoInstrument="true" />
  <threadProfiling>
    <ignoreMethod>System.Threading.WaitHandle:InternalWaitOne</ignoreMethod>
    <ignoreMethod>System.Threading.WaitHandle:WaitAny</ignoreMethod>
  </threadProfiling>
  <applicationLogging enabled="false">
    <forwarding enabled="true" />
  </applicationLogging>
</configuration>
  ```
</details>


<details>
  <summary>C:\Program Files\New Relic\newrelic-infra</summary>
  ```

  ```
</details>


<details>
  <summary>C:\Program Files\New Relic\newrelic-infra\newrelic-infra.yml</summary>
  ```
# THIS FILE IS MACHINE GENERATED
license_key: NEW_RELIC_LICENSE_KEY
enable_process_metrics: true
status_server_enabled: true
status_server_port: 18003
  ```
</details>


<details>
  <summary>C:\Program Files\New Relic\newrelic-infra\logging.d\logs.yml</summary>
  ```
logs:
  # - name: windows-security
    # winlog:
      # channel: Security
      # collect-eventids:
      # - 4740
      # - 4728
      # - 4732
      # - 4756
      # - 4735
      # - 4624
      # - 4625
      # - 4648

  # - name: windows-application
    # winlog:
      # channel: Application

  - name: newrelic-cli.log
    file: C:\Users\Administrator\.newrelic\newrelic-cli.log
    attributes:
      newrelic-cli: true

## Transferred to Fluent Bit config due to multiline logs (fluent-bit running as a service)
## C:\Program Files\New Relic\newrelic-infra\newrelic-integrations\logging\fluent-bit.conf
#  - name: salesrun-api
#    file: F:\storage\logs\api*.log
#    attributes:
#      logtype: fileRaw  
    
#  - name: salesrun-cli
#    file: F:\storage\logs\cli*.log
#    attributes:
#      logtype: fileRaw  
    
#  - name: salesrun-migrator
#    file: F:\storage\logs\migrator*.log
#    attributes:
#      logtype: fileRaw
  ```
</details>

<details>
  <summary>C:\Program Files\New Relic\newrelic-infra</summary>
  ```

  ```
</details>

<details>
  <summary>C:\Program Files\New Relic\newrelic-infra</summary>
  ```

  ```
</details>