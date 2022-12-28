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
