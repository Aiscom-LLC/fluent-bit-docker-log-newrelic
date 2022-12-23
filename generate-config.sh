# test service
# >test.log && >test1.log && /opt/fluent-bit/bin/fluent-bit -c /etc/fluent-bit/fluent-bit.conf -vvv
# ./add.sh
source ./.env
if [ "${FLUENT_BIT_DIR: -1}" != "/" ]; then FLUENT_BIT_DIR="${FLUENT_BIT_DIR}/"; fi
if [[ ! -f "./containers.json" ]]; then echo "Configure containers.json" && exit; fi
containers=$(cat './containers.json')
input_tmpl="./templates/container-log-input.tmpl"
inputs_conf="${FLUENT_BIT_DIR}conf/container-log-inputs.conf"
capture_filter_tmpl="./templates/capture-message-filter.tmpl"
capture_filters_conf="${FLUENT_BIT_DIR}conf/capture-message-filters.conf"
parser_tmpl="./templates/container-log-parsers.tmpl"
parsers_conf="${FLUENT_BIT_DIR}conf/container-log-parsers.conf"
multiline_filter_tmpl="./templates/multiline-filter.tmpl"
multiline_filters_conf="${FLUENT_BIT_DIR}conf/multiline-filters.conf"
first_symbol_parser_tmpl="./templates/first-symbol-parsers.tmpl"
first_symbol_parser_conf="${FLUENT_BIT_DIR}conf/first-symbol-parsers.conf"
pre_output_filters_tmpl="./templates/pre-output-filters.tmpl"
pre_output_filters_conf="${FLUENT_BIT_DIR}pre-output-filters.conf"
outputs_tmpl="./templates/outputs.tmpl"
outputs_conf="${FLUENT_BIT_DIR}conf/outputs.conf"
plugin_tmpl="./templates/newrelic-fluent-bit-plugin.tmpl"
plugin_conf="${FLUENT_BIT_DIR}conf/newrelic-fluent-bit-plugin.conf"
config_tmpl="./templates/fluent-bit.tmpl"
config_conf="${FLUENT_BIT_DIR}fluent-bit.conf"

# Default first line of the logs is 'square-bracket' ('\[' in regex)
first_line_bracket='square-bracket'
# Another first line symbol is 'letter' ('\w' in regex)
first_line_letter='letter'

# Fix
# include all symbols in message [\w\d\s#$%^(){}|;:,'"\/\.\-\=\+\*\r\n&@!\\]*
# regex example ^\[(?<timestamp>\d*)\] (?<level>\w*)[ ]{1,2}(?<message>[\w\d\s%@(){}\[\];:'"\/\.\-\=\+\*\r\n\\#$|\^]*)
parser_fix="[\\\\\\\w\\\\\\\d\\\\\\\s%@(){}\\\\\\\[\\\\\\\];:,'\"\\\\\\\\\\\\\/\\\\\\\.\\\\\\\-\\\\\\\=\\\\\\\+\\\\\\\*\\\\\\\\\\\\\\\r\\\\\\\\\\\\\\\n\\\\\\\\\\\\\\\\\\\\\\\#$|\\\\\\\^]*"

# Check
if [ "$OUTPUT_NEW_RELIC" == "true" ]; then
  if [[ "$NEW_RELIC_API_KEY" == "" || "$NEW_RELIC_ENDPOINT" == "" ]]; then
    echo "Specify NEW_RELIC_API_KEY and/or NEW_RELIC_ENDPOINT variables in .env"
    exit 1
  fi
fi


# Copy files
if [[ ! -d "${FLUENT_BIT_DIR}conf/" ]]; then
  cp $pre_output_filters_tmpl $pre_output_filters_conf
  cp $config_tmpl $config_conf
  sed -i "s@{{FLUENT_BIT_DIR}}@$FLUENT_BIT_DIR@g" $config_conf
  cp -r ./pre-output-filters ${FLUENT_BIT_DIR}
  mkdir "${FLUENT_BIT_DIR}conf/"
  mkdir "${FLUENT_BIT_DIR}db-log/"
else
  rm -f ${FLUENT_BIT_DIR}conf/*
  rm -f ${FLUENT_BIT_DIR}db-log/*
fi
rm -f ${FLUENT_BIT_DIR}*.db
cp $first_symbol_parser_tmpl $first_symbol_parser_conf


# Generate plugin config
newrelic_fluent_bit_plugin=$( echo "$NEW_RELIC_FLUENT_BIT_PLUGIN_URL" | awk -F'/' '{print $NF}')
if [[ ! -f "${FLUENT_BIT_DIR}${newrelic_fluent_bit_plugin}" ]]; then wget "$NEW_RELIC_FLUENT_BIT_PLUGIN_URL" -O "${FLUENT_BIT_DIR}$newrelic_fluent_bit_plugin"; fi
cp $plugin_tmpl $plugin_conf
sed -i -e "s@{{newrelic_fluent_bit_plugin}}@${FLUENT_BIT_DIR}$newrelic_fluent_bit_plugin@" $plugin_conf


# Generate outputs config
cp $outputs_tmpl $outputs_conf
if [ "$OUTPUT_STDOUT" == "true" ]; then sed -i -e "s@#stdout#@@g" $outputs_conf; fi
if [ "$OUTPUT_NEW_RELIC" == "true" ]; then sed -i -e "s@#newrelic#@@g" $outputs_conf; fi
sed -i -e "s@{{licenseKey}}@$NEW_RELIC_API_KEY@g" -e "s@{{endpoint}}@$NEW_RELIC_ENDPOINT@g" $outputs_conf


# Generate config for container logs
echo 'Generate config in fluent-bit for containers:'
for k in $( jq -r 'keys | .[]' <<< $containers ); do
    container=$( jq -r ".[$k]" <<< $containers )
    container_name=$( jq -r '.container_name' <<< $container )
    parser=$( jq -r '.parser' <<< $container )
    first_line=$( jq -r '.first_line' <<< $container )
    next_lines=$( jq -r '.next_lines' <<< $container )

    if [[ "$container_name" == "null" || "$container_name" == "" ]]; then
        echo 'Error: container name can not be empty'
        exit 1
    fi
    if [[ "$parser" == "null" || "$parser" == "" ]]; then
        echo 'Error: parser regex can not be empty'
        exit 1
    fi
    if [[ "$first_line" == "square-bracket" || "$first_line" == "[" || "$first_line" == "null" || "$first_line" == "" ]]; then
        first_line=$first_line_bracket
    fi
    if [[ "$first_line" == "letter" ]]; then
        first_line=$first_line_letter
    fi
    echo -e " - ${container_name} (first line '$first_line')"

    # Inputs
    input_tmpl__=$( sed -e "s/{{container_name}}/$container_name/" -e "s@{{FLUENT_BIT_DIR}}@$FLUENT_BIT_DIR@g" $input_tmpl )
    echo -e "${input_tmpl__}\n\n">>$inputs_conf

    # Concatenate multiline logs
    multiline_filter_tmpl__=$( sed \
        -e "s/{{container_name}}/$container_name/" \
        -e "s/{{first_line}}/$first_line/" \
        -e "s/{{next_lines}}/$next_lines/" \
        $multiline_filter_tmpl )
    echo -e "${multiline_filter_tmpl__}\n\n">>$multiline_filters_conf

    # Capture filters
    capture_filter_tmpl__=$( sed -e "s/{{container_name}}/$container_name/" $capture_filter_tmpl )
    echo -e "${capture_filter_tmpl__}\n\n">>$capture_filters_conf

    # Parser
    parser=$( echo "$parser" | sed "s/<message>.*)/<message>$parser_fix)/" )
    parser_tmpl__=$( sed -e "s/{{container_name}}/$container_name/" -e "s/{{parser}}/$parser/" $parser_tmpl )
    echo -e "${parser_tmpl__}\n\n">>$parsers_conf


    container=null
    container_name=null
    parser=null
    input_tmpl__=null
    multiline_tmpl__=null
    capture_filter_tmpl__=null
    parser_tmpl__=null
    first_line=null
    next_lines=null
done

