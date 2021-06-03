#!/bin/bash

ARGV=("$@")

if ! command -v jq &> /dev/null; then
    echo "jq could not be found; please run apt-get install jq"
    exit
fi

if ! command -v yq &> /dev/null; then
    echo "yq could not be found; please run pip3 install yq"
    exit
fi

# Only augment config/auth list commands
# this heuristic looks for the first and second non-flag parameter
# which can be be fooled by flags that take parameters
cmd=""
augment=false
for var in "$@"; do
    if [[ "${var}" == -* ]]; then
        continue
    fi
    if [[ -z "${cmd}" ]]; then
        if [[ "${var}" == "config" ]] || [[ "${var}" == "auth" ]]; then
            cmd="${var}"
            continue
        fi
    else
        if [[ "${var}" == "list" ]]; then
            augment=true
        else
            break
        fi
    fi
done

# Run command without augmentation
if [[ "${augment}" == "false" ]]; then
    exec gcloud "$@"
fi

format=""

# Find last --format command
for ((pos = ${#ARGV[@]} - 1; pos >= 0; pos--)); do
    var=${ARGV[pos]}
    if [[ "${var}" == --format=* ]]; then # wildard match don't quote
        if [[ "${var}" == "--format=yaml" ]]; then
            format=yaml
            break
        fi
        if [[ "${var}" == "--format=json" ]]; then
            format=json
            break
        fi
        break
    fi
    if [[ "${var}" == "--format" ]]; then
        if [[ "${ARGV[$pos + 1]}" == "yaml" ]]; then
            format=yaml
        fi
        if [[ "${ARGV[$pos + 1]}" == "json" ]]; then
            format=json
        fi
        break
    fi
done

# Acquire ADC source
ADC=""
SOURCE=""
TOKEN=$(gcloud auth application-default print-access-token 2> /dev/null)
if (($? == 0)); then
    if [[ -z "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        SVC_EMAIL=$(curl -s -m 1 --connect-timeout 1 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")
        if (($? == 0)); then
            ADC="${SVC_EMAIL}"
            SOURCE="metadata"
        else
            ADC=$(curl -s "https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=${TOKEN}" | jq -r '.email')
            ## gcloud does allow overridng the config folder but i'll ignore that here for now...
            SOURCE="$HOME/.config/gcloud/application_default_credentials.json"
        fi
    else
        #ADC=$(curl -s https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$TOKEN | jq -r '.azp')
        TYPE=$(jq -r '.type' < "${GOOGLE_APPLICATION_CREDENTIALS}")
        if [ "$TYPE" == "service_account" ]; then
            ADC=$(jq -r '.client_email' < "${GOOGLE_APPLICATION_CREDENTIALS}")
        fi

        # gcloud does not yet support  external_account types...once it does, find a better indicator of the identity
        #   than .subject_token_type (whch isn't even an identity)
        if [ "$TYPE" == "external_account" ]; then
            ADC=$(jq -r '.subject_token_type' < "${GOOGLE_APPLICATION_CREDENTIALS}")
        fi
        SOURCE="$GOOGLE_APPLICATION_CREDENTIALS"
    fi
fi

case "${format}" in
    yaml)
        gcloud "$@" | yq -y ". |= .+ {\"adc\": {\"account\":\"$ADC\", \"source\":\"$SOURCE\"}}"
        ;;
    json)
        case "${cmd}" in
            config)
                gcloud "$@" | jq ". |= .+ {\"adc\":{\"account\":\"$ADC\", \"source\":\"$SOURCE\"}}"
                ;;
            auth)
                gcloud "$@" | jq ".[] |= .+ {\"adc\":{\"account\":\"$ADC\", \"source\":\"$SOURCE\"}}"
                ;;
        esac
        ;;
    *)
        echo "[adc]"
        echo "account = $ADC"
        echo "source = $SOURCE"
        echo ""
        gcloud "$@"
        ;;
esac