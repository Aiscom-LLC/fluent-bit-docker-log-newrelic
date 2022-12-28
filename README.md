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
