# Install Newrelic

`Newrelic Dashboard -> +Add Data -> Guided install -> Installation plan`

Newrelic is able to monitor system and application logs through its agent:
System&app logs => newrelic agent => Newrelic
But we use Fluent-bit for advanced managing application logs:
App logs => Fleunt-bit => Newrelic

## Fluent-bit on Windows
Newrelic provides preinstalled fluent-bit plugin in C:\Program Files\New Relic\newrelic-infra\newrelic-integrations\logging
Otherwise you can download newer version of Fluent-bit from https://docs.fluentbit.io/manual/installation/windows
Paste configuration files from repository to Fleutn-bit config directory (logging in preinstalled case)
Fluent-bit tracks log files, then filters, modifies and forwards to newrelic
