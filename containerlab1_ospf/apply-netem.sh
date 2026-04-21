#!/bin/bash
# Apply tc netem delays to the outbound WAN interface on nw-c1-m1.
# This simulates WAN latency between the client cluster and C2 services.
#
# Usage: ./apply-netem.sh <delay> <loss>
# Examples:
#   ./apply-netem.sh 30ms 1%
#   ./apply-netem.sh 80ms 0.5%
# Defaults: 30ms delay, 1% loss
#
# Run on: nw-c1-m1

DELAY=${1:-30ms}
LOSS=${2:-1%}
IFACE=${3:-ens3}

sudo tc qdisc replace dev $IFACE root netem delay $DELAY loss $LOSS
echo "$IFACE: delay=$DELAY loss=$LOSS applied"
