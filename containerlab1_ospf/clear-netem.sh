#!/bin/bash
# Remove tc netem rules from the outbound WAN interface on nw-c1-m1.
#
# Run on: nw-c1-m1

IFACE=${3:-ens3}

sudo tc qdisc del dev $IFACE root 2>/dev/null || true
echo "$IFACE: netem cleared"
