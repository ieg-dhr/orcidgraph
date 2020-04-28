#!/bin/bash -e

docker run --rm -ti \
  --publish=7474:7474 \
  --publish=7687:7687 \
  --env=NEO4J_AUTH=none \
  --volume="$(pwd)/../cache/neo_data:/data" \
  neo4j:3.5.15
