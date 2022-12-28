# Install Newrelic

Follow instruction in 
`Newrelic Dashboard -> +Add Data -> Guided install -> Installation plan`

Newrelic is able to monitor system and application logs through its agent:
`System & app logs => newrelic agent => Newrelic`
But we use Fluent-bit for advanced managing application logs:
`App logs => Fleunt-bit => Newrelic`

## Fluent-bit on Windows
Newrelic provides preinstalled fluent-bit plugin in `New Relic\newrelic-infra\newrelic-integrations\logging` folder. 
Otherwise you can download newer version of Fluent-bit from https://docs.fluentbit.io/manual/installation/windows. 
Paste configuration files from repository to Fleutn-bit config directory (logging in preinstalled case) and change NEW_RELIC_LICENSE_KEY
Fluent-bit tracks, parsers, filters, modifies and forwards logs to Newrelic

See Fleunt-bit flow log for more details:
![alt text](https://github.com/Maksim-ops/fluent-bit-docker-log-newrelic/blob/newrelic-for-windows/Fluent-bit-Flow-Windows-logs.jpg?raw=true)

-----------------------------------------------------------------------------------

# Make monitoring in Newrelic


For monitoring microservices by url Create monitor in "Synthetic monitoring" module: select 'Ping' monitor type for common simple cases.
Specify name and url. Check Advanced options. Note: 'Bypass HEAD request' may cause errors if IIS doesn't allow header requests (to check exec command `curl -I $url`)
To creaete advanced monitoring with specidic action select 'Scripted browser' type. 


<details>
  <summary>Monitoring script for SFTP</summary>

  ```
// https://discuss.newrelic.com/t/proactively-monitor-non-http-connections-with-new-relic-synthetics/118646
// https://discuss.newrelic.com/t/relic-solution-ftp-sftp-ldap-tcp-and-smtp-examples/118661
// https://www.npmjs.com/package/ssh2-sftp-client
const Client = require('ssh2-sftp-client');
const config = {
  host: $secure.SFTP_HOST,
  port: $secure.SFTP_PORT,
  username: 'vs',
  strictVendor: false,
  privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----\n<private key>\n-----END OPENSSH PRIVATE KEY-----',
  algorithms: { serverHostKey: [ 'ssh-ed25519' ] },
  //debug: msg => { console.error(msg); },
  remotePath: '/vs'
}
const sftp = new Client();
sftp.connect(config)
// uncomment to check listing 
/*.then(() => { return sftp.list(config.remotePath); })
.then(data => { console.log(data); })*/
.then(function (){ return sftp.end(); })
.catch(function(err) { throw err; })
  ```
</details>


<details>
  <summary>Monitoring script for SMTP</summary>
  ```
// https://discuss.newrelic.com/t/proactively-monitor-non-http-connections-with-new-relic-synthetics/118646
// https://discuss.newrelic.com/t/relic-solution-ftp-sftp-ldap-tcp-and-smtp-examples/118661
var assert = require('assert');
var nodemailer = require('nodemailer');

let transporter = nodemailer.createTransport({
    host: $secure.SMTPQBSERVER,
    port: 587,
    auth: {
        user: $secure.NOREPLYMAIL,
        pass: $secure.NOREPLYMAILPASSWORD
   }
});

var message = {
    from: $secure.NOREPLYMAIL,
    to: $secure.QBMAIL,
    subject: 'Test message from New Relic Synthetic monitor',
    text: 'Testing the nodemailer package.',
}

transporter.sendMail(message, function(err, info, response){
    assert.ok(!err, "Error sending email: "+err)
})
  ```
</details>


## Make Alerts

after making monitors it's necessary to make alerts to get notifications

### 1. Create workflows

Workflows allows to send notifications to channels according the data filters.
Filter can include various criteries such as priority, policy name, other mwssage fields.
We use 2 channels: email amd telegram.
For emails channel workflow uses following filter:
`accumulations.policyName contains email AND priority equals CRITICAL OR HIGH`
Add email channel and specify emails

For telegram channel workflow uses following filter:
`accumulations.policyName contains telegram AND priority equals CRITICAL`
Add webhook channel with template:
```
{
  "chat_id": "${CHAT_ID}",
  "disable_notification": false,
  "parse_mode": "HTML",
  "text": "Newrelic\nHost: {{entitiesData.names.[0]}}\nCondition: {{accumulations.conditionName.[0]}}\nPriority: {{ priority }}\nTotal incidents: {{totalIncidents}}\nState {{state}}\nStatus: {{status}}\nIssue url: <a href=\"{{issuePageUrl}}\">link</a>"
}
```

### 3. Create destinations.

Create webhook destination to send notifications to telegram
Specify Endpoint URL:
```
https://api.telegram.org/bot${BOT_API_TOKEN}/sendMessage
```
This destination should be selected in telegram workflow

### 4. Create policies

Policy is a condition set by which data is tracked and if it exceeded condition threshold policy create issue that forward to workflow.
Policy create issue in three ways: 
1) one issue per policy
2) one issue per condition
3) one issue per incident
Each way affects which messages and how often it will come to the channels
We groupped policies by virtual servers, Synthetic monitoing and microservices and select 2 way
For instance, condition for memory of  Webapp server contains following instructions:
```
Name: Memoru usage below 30%
NRQL: SELECT average(host.memoryFreePercent) FROM Metric WHERE host.hostname='WEBAPP'
Priority level Critical: Metric query result is < 10.0 for at least 5 mins
Priority level Warning: Metric query result is < 30.0 for at least 5 mins
Window duration: 1 min
Delay: 2 min
```

