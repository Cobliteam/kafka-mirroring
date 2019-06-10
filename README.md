# kafka-mirroring

## Why? 
[MirrorMaker](https://kafka.apache.org/documentation/#basic_ops_mirror_maker) itself does not replicate topics metadata.

[uReplicator](https://github.com/uber/uReplicator) needs destination Zookeeper (not always avaiable).

## How?

This _mixin container_ uses the [giogt MirrorMaker container](https://hub.docker.com/r/giogt/kafka-mirror-maker) with [Kafka Topic Mirror](https://github.com/Cobliteam/kafka-topic-mirror) in order to provide a containerized solution for a full Kafka mirroring, including new topic identification/replication  

It runs [Kafka Topic Mirror](https://github.com/Cobliteam/kafka-topic-mirror) from time to time, creating new topics on destination Kafka with same metadata (name, replication factor, partitions and configuration) as source.

Topics creation triggers [MirrorMaker](https://kafka.apache.org/documentation/#basic_ops_mirror_maker) restart in order to start data replication over new topics.

## Usage

Most of environment variables are equivalent to [giogt's](https://github.com/giogt/docker-kafka/tree/master/kafka-mirror-maker#usage) ones.

There are several [default's env vars](Dockerfile#19) for mirror maker optimization

Minimal usage needs source zookeeper/kafka source and kafka destination connection strings

```bash
$ docker run -e MIRROR_MAKER_CONSUMER_ZOOKEEPER_CONNECT=zoo010:2181 \
             -e MIRROR_MAKER_CONSUMER_BOOTSTRAP_SERVERS=kafka010:9092 \
             -e MIRROR_MAKER_PRODUCER_BOOTSTRAP_SERVERS=kafka210:9092 \
             cobli/kafka-mirroring
``` 

