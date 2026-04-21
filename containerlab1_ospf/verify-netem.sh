#!/bin/bash
# Show current tc qdisc state on WAN entry and exit interfaces.

for NODE in lan1host lan2host; do
  echo "=== $NODE eth1 ==="
  sudo docker exec clab-pa3wan-$NODE tc qdisc show dev eth1
done
