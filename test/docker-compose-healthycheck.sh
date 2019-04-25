#!/usr/bin/env bash

ctnr_name=$(docker-compose ps -q $1)

while true; do
    status=$(docker inspect -f '{{.State.Health.Status}}' "$ctnr_name")
    [[ "$status" != "healthy" ]] || break
    sleep 1
done