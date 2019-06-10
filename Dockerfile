FROM cobli/kafka-topic-mirror:0.0.1 as topic-mirror

FROM giogt/kafka-mirror-maker:2.0.0 as mirror-maker


FROM confluentinc/cp-kafka:5.2.1

# jessie repos are archived: we need to change repos URL and remove updates entry
# in order to keep apt working
RUN sed -i "s/^deb.\+deb\.debian\.org\/debian.\+jessie-updates.\+main//" /etc/apt/sources.list
RUN sed -i "s/deb\.debian\.org/archive.debian.org/" /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor=3.* \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /app

COPY --from=mirror-maker /etc/giogt/ /etc/giogt/
ENV COMPONENT=kafka-mirror-maker
RUN mkdir -p /etc/"${COMPONENT}"

COPY --from=topic-mirror /app/kafka-topic-mirror.jar /app/
COPY --from=topic-mirror /app/entrypoint.sh /app/kafka-topic-mirror.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start.sh kafka-topic-mirror.log4j.properties.template /app/

ENV MIRROR_MAKER_WHITELIST=".*" \
    MIRROR_MAKER_OPTS="--abort.on.send.failure=true" \
    MIRROR_MAKER_CONSUMER_EXCLUDE_INTERNAL_TOPICS=true \
    MIRROR_MAKER_CONSUMER_ENABLE_AUTO_COMMIT=false \
    MIRROR_MAKER_CONSUMER_GROUP_ID=kafka-mirroring-group \
    MIRROR_MAKER_CONSUMER_CLIENT_ID=kafka-mirroring \
    MIRROR_MAKER_CONSUMER_AUTO_OFFSET_RESET=earliest \
    MIRROR_MAKER_PRODUCER_MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION=1 \
    MIRROR_MAKER_PRODUCER_BATCH_SIZE=100 \
    MIRROR_MAKER_PRODUCER_RETRIES=99999999 \
    MIRROR_MAKER_PRODUCER_MAX_BLOCK_MS=99999999 \
    MIRROR_MAKER_PRODUCER_ACKS=-1 \
    MIRROR_MAKER_PRODUCER_CLIENT_ID=kafka-mirroring \
    KAFKA_LOG4J_OPTS="-Dlog4j.configuration=file:/etc/kafka-mirror-maker/log4j.properties" \
    TOPIC_MIRROR_LOG4J_OPTS="-Dlog4j.configuration=file:/app/kafka-topic-mirror.log4j.properties" \
    TOPIC_MIRROR_LOG4J_ROOT_LOGLEVEL=WARN

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD supervisorctl status kafka-mirror-maker | awk '{print $2}' | grep RUNNING || exit 1

CMD ["/app/start.sh"]
