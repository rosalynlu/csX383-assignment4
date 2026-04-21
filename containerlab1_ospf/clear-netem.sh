#!/bin/bash
# Remove tc netem rules from WAN entry and exit interfaces.

for NODE in lan1host lan2host; do
  sudo docker exec clab-pa3wan-$NODE tc qdisc del dev eth1 root 2>/dev/null || true
  echo "$NODE eth1: netem cleared"
done
