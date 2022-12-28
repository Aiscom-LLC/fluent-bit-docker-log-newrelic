# Generate in Ubuntu fluent-bit config for processing docker container logs and forwarding to Newrelic

## Fluent bit installation

### 1. Install newrelic agent infrastracture

```
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=<new_relic_api_key> NEW_RELIC_ACCOUNT_ID=3293200 NEW_RELIC_REGION=EU /usr/local/bin/newrelic install
```

### 2. Install fluent-bit
https://docs.fluentbit.io/manual/installation/linux/ubuntu
```
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
```

### 3. Specify env variables
```
cp .env.template .env
NEWRELIC_LICENSE_KEY=<yout_new_relic_license_key>
NEWRELIC_ENDPOINT=<new_relic_endpoint>
```

### 4. Generate config
```
./generate-config.sh
```
Will generate config in $FlUENT_BIT_DIR and all accompanying parsers and filters.


## Fluent bit Flow parsing logs
Docker writes container logs to corresponging folders by id container (with default log engine "json-file").
```
/var/lib/docker/containers/<container_id>/<container_id>-json.log
```
So it's impossible to spesify inputs for fluent-bit for tracking files from known folders.
I tried another way to use fluent-bit engine but it is not reliable in production because 
if the fluent-bit crashes then the container using fluent-bit for log will stop
That's why every INPUT tracks every container logs from `/var/lib/docker/containers/*/*log` and try to parse.
Each docker container log conforms to the format:
```
{"log":"<container_message>","stream":"stdout","attrs":{"tag":"<container_name>"},"time":"2022-12-23T08:04:13.237849125Z"}
```

If the parsing was successful, then the message is follow to the next step. 
A necessary condition for successful parsing is the tag of the container name.
To specify tag with container name it necessary to include instructions to the docker-compose file in the container service:
```
container_name: <your_container_name>
logging:
  options:
    tag: "{{.Name}}"
```
Every INPUT has a parser for corresponding container:
```
^{"log":"(?<log>.*)","stream":"(?<stream>stdout|stderr)","attrs":{"tag":"(?<container_name>{{container_name}})"},"time":"(?<timestamp>[^\]]*)Z"}
```
Parsing will succeed if the {{container_name}} in parser matches to container_name. If not succeed, the message will exclude from fluent-bit flow.
Then the message is assembled into a multiline message, is parsed by specific fields, is transformed by lua script and is sent to Newrelic

See Fleunt bit flow log
![alt text](https://github.com/Maksim-ops/fluent-bit-docker-log-newrelic/blob/main/Fluent-bit-Flow-Docker-logs.jpg?raw=true)


-----------------------------------------------------------------------------------

Make monitoring in Newrelic


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

### 3. Create policies
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

