#!/usr/bin/env bash

set -e
set -x

DOCKER_UP_TIMEOUT=60

echo "setting up test environment"
docker-compose up -d zoo010
timeout ${DOCKER_UP_TIMEOUT} ./docker-compose-healthycheck.sh zoo010
docker-compose up -d kafka010
timeout ${DOCKER_UP_TIMEOUT} ./docker-compose-healthycheck.sh kafka010
docker-compose up -d zoo210
timeout ${DOCKER_UP_TIMEOUT} ./docker-compose-healthycheck.sh zoo210
docker-compose up -d kafka210
timeout ${DOCKER_UP_TIMEOUT} ./docker-compose-healthycheck.sh kafka210
docker-compose up -d kafka-mirroring
timeout ${DOCKER_UP_TIMEOUT} ./docker-compose-healthycheck.sh kafka-mirroring

echo "creating test topic"
docker-compose exec kafka010\
    kafka-topics --create --topic test --zookeeper zoo010:2181 \
    --replication-factor 1 --partitions 3 --if-not-exists

echo "producing a test message"
echo "test" | docker exec -i "$(docker-compose ps -q kafka010)"\
    kafka-console-producer --broker-list kafka010:9092 --topic test

echo "consuming test message"
docker-compose exec kafka210 timeout 10 \
    kafka-console-consumer --bootstrap-server kafka210:9092 --topic test \
    --group test_group --from-beginning --max-messages 1 | grep test

