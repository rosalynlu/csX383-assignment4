#!/bin/bash
# Apply tc netem delays to the WAN entry and exit interfaces.
# Traffic from C1 enters the WAN through lan1host:eth1 and
# returns from C2 through lan2host:eth1, so impairments on
# both interfaces degrade the full request+response RTT.
#
# Usage: ./apply-netem.sh <delay> <loss>
# Examples:
#   ./apply-netem.sh 30ms 1%
#   ./apply-netem.sh 80ms 0.5%
# Defaults: 30ms delay, 1% loss

DELAY=${1:-30ms}
LOSS=${2:-1%}

for NODE in lan1host lan2host; do
  sudo docker exec clab-pa3wan-$NODE tc qdisc replace dev eth1 root netem delay $DELAY loss $LOSS
  echo "$NODE eth1: delay=$DELAY loss=$LOSS applied"
done
