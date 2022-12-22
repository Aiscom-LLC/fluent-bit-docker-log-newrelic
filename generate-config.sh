# test service
# >test.log && >test1.log && /opt/fluent-bit/bin/fluent-bit -c /etc/fluent-bit/fluent-bit.conf -vvv
# ./add.sh
source .env
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
outputs_tmpl="./templates/outputs.tmpl"
outputs_conf="${FLUENT_BIT_DIR}conf/outputs.conf"
plugin_tmpl="${FLUENT_BIT_DIR}templates/newrelic-fluent-bit-plugin.tmpl"
plugin_conf="${FLUENT_BIT_DIR}conf/newrelic-fluent-bit-plugin.conf"


# Default first line of the logs is 'square-bracket' ('\[' in regex)
first_line_bracket='square-bracket'
# Another first line symbol is 'letter' ('\w' in regex)
first_line_letter='letter'

# Fix
# include all symbols in message [\w\d\s#$%^(){}|;:,'"\/\.\-\=\+\*\r\n&@!\\]*
# regex example ^\[(?<timestamp>\d*)\] (?<level>\w*)[ ]{1,2}(?<message>[\w\d\s%@(){}\[\];:'"\/\.\-\=\+\*\r\n\\#$|\^]*)
parser_fix="[\\\\\\\w\\\\\\\d\\\\\\\s%@(){}\\\\\\\[\\\\\\\];:,'\"\\\\\\\\\\\\\/\\\\\\\.\\\\\\\-\\\\\\\=\\\\\\\+\\\\\\\*\\\\\\\\\\\\\\\r\\\\\\\\\\\\\\\n\\\\\\\\\\\\\\\\\\\\\\\#$|\\\\\\\^]*"

# Check
if [ "$OUTPUT_NEWRELIC" == "true" ]; then
  if [[ "$NEWRELIC_LICENSE_KEY" == "" || "$NEWRELIC_ENDPOINT" == "" ]]; then
    echo "Specify NEWRELIC_LICENSE_KEY and/or NEWRELIC_ENDPOINT variables in .env"
    exit 1
  fi
fi


# Common parser
[[ ! -d "${FLUENT_BIT_DIR}conf/" ]] && mkdir "${FLUENT_BIT_DIR}conf/"
cp $first_symbol_parser_tmpl $first_symbol_parser_conf
cp ${FLUENT_BIT_DIR}fluent-bit.conf ${FLUENT_BIT_DIR}fluent-bit.conf.copy
cp ./fluent-bit.conf ${FLUENT_BIT_DIR}fluent-bit.conf

# Generate plugin config
newrelic_fluent_bit_plugin=$( echo $NEWRELIC_FLUENT_BIT_PLUGIN_URL | awk -F'/' '{print $NF}')
if [[ ! -f "${FLUENT_BIT_DIR}${newrelic_fluent_bit_plugin}" ]]; then wget $NEWRELIC_FLUENT_BIT_PLUGIN_URL -O "${FLUENT_BIT_DIR}$newrelic_fluent_bit_plugin"; fi
cp $plugin_tmpl $plugin_conf
sed -i -e "s@{{newrelic_fluent_bit_plugin}}@${FLUENT_BIT_DIR}$newrelic_fluent_bit_plugin@" $plugin_conf


# Generate outputs config
cp $outputs_tmpl $outputs_conf
if [ "$OUTPUT_STDOUT" == "true" ]; then sed -i -e "s@#stdout#@@g" $outputs_conf; fi
if [ "$OUTPUT_NEWRELIC" == "true" ]; then sed -i -e "s@#newrelic#@@g" $outputs_conf; fi
sed -i -e "s@{{licenseKey}}@$NEWRELIC_LICENSE_KEY@g" -e "s@{{endpoint}}@$NEWRELIC_ENDPOINT@g" $outputs_conf


# Generate config for container logs
rm -f "${FLUENT_BIT_DIR}conf/*"
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
    input_tmpl__=$( sed -e "s/{{container_name}}/$container_name/" $input_tmpl )
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

