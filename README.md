# Generate in Ubuntu fluent-bit config for processing docker container logs and forwarding to Newrelic

## 1. Install newrelic agent infrastracture

```
curl -Ls https://download.newrelic.com/install/newrelic-cli/scripts/install.sh | bash && sudo NEW_RELIC_API_KEY=<new_relic_api_key> NEW_RELIC_ACCOUNT_ID=3293200 NEW_RELIC_REGION=EU /usr/local/bin/newrelic install
```

## 2. Install fluent-bit
https://docs.fluentbit.io/manual/installation/linux/ubuntu
```
curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
```
