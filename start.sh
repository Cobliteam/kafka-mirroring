#!/usr/bin/env bash

set -e

#trap crtl+c on docker run
trap 'exit 1' INT

function main {

    validate_variable "MIRROR_MAKER_CONSUMER_ZOOKEEPER_CONNECT"
    validate_variable "MIRROR_MAKER_CONSUMER_BOOTSTRAP_SERVERS"
    validate_variable "MIRROR_MAKER_PRODUCER_BOOTSTRAP_SERVERS"

    /usr/bin/supervisord -c /etc/supervisor/supervisord.conf

    dub template "/app/kafka-topic-mirror.log4j.properties.template" "/app/kafka-topic-mirror.log4j.properties"

    run_kafka_topic_mirror

    echo "Starting mirror maker"

    supervisorctl start kafka-mirror-maker-init

    # exits, but stops mirror maker before doing it
    trap stop_mirror_maker EXIT

    wait_mirror_maker_for_status "RUNNING"

    while true
    do
            topic_mirror_result=$(run_kafka_topic_mirror)

            if [[ $? -ne 0 ]]; then
                echo "error running topic mirror - exiting container"
                exit 1
            fi

            if echo "${topic_mirror_result}" | tee /proc/1/fd/1 | grep -q "creating topic"
            then
                restart_mirror_maker
            else
                echo "waiting for topic creation.."
                ensure_mirror_maker_running
                sleep 10
            fi
    done
}

function validate_variable {
    local var=$1
    if [[ -z "${!var}" ]]
    then
        echo "No $var env var set"
        exit 1
    fi
}


function run_kafka_topic_mirror {
    local dst_props=()

    [[ -v MIRROR_MAKER_PRODUCER_SECURITY_PROTOCOL ]] && \
    export COMMAND_CONFIG_PROPERTY_DST_SECURITY_PROTOCOL=$MIRROR_MAKER_PRODUCER_SECURITY_PROTOCOL

    [[ -v MIRROR_MAKER_PRODUCER_SASL_MECHANISM ]] && \
    export COMMAND_CONFIG_PROPERTY_DST_SASL_MECHANISM=$MIRROR_MAKER_PRODUCER_SASL_MECHANISM

    [[ -v MIRROR_MAKER_PRODUCER_CLIENT_ID ]] && \
    export COMMAND_CONFIG_PROPERTY_DST_CLIENT_ID=$MIRROR_MAKER_PRODUCER_CLIENT_ID

    [[ -v MIRROR_MAKER_PRODUCER_SASL_JAAS_CONFIG ]] && \
    export COMMAND_CONFIG_PROPERTY_DST_SASL_JAAS_CONFIG=$MIRROR_MAKER_PRODUCER_SASL_JAAS_CONFIG

    /app/kafka-topic-mirror.sh --mirror \
            --zookeeper-src "${MIRROR_MAKER_CONSUMER_ZOOKEEPER_CONNECT}" \
            --bootstrap-servers-dst "${MIRROR_MAKER_PRODUCER_BOOTSTRAP_SERVERS}"

}

function mirror_maker_status {
    supervisorctl status kafka-mirror-maker | awk '{print $2}'
}

function ensure_mirror_maker_running {
    local status=$(mirror_maker_status)
    [[ "${status}" = "RUNNING" ]] || exit 1
}


function wait_mirror_maker_for_status {
    local expected_status=$1
    for try in {1..10} ; do

        local status=$(mirror_maker_status)

        echo "waiting for mirror maker to change status from ${status} to ${expected_status} ${try}/10"

        if [[ "${status}" = "${expected_status}" ]]; then
            return
        fi
        sleep 1
    done
    exit 1
}

function stop_mirror_maker {
    local status=$(mirror_maker_status)
    if [[ ${status} =~ ^(RUNNING|STARTING|BACKOFF)$ ]]; then
        supervisorctl stop kafka-mirror-maker
        wait_mirror_maker_for_status "STOPPED"
    fi
}

function start_mirror_maker {
    supervisorctl start kafka-mirror-maker
    wait_mirror_maker_for_status "RUNNING"
}

function restart_mirror_maker {
    stop_mirror_maker
    start_mirror_maker
}

main "$@"
