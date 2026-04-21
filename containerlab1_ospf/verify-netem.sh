#!/bin/bash
# Show current tc qdisc state on the outbound WAN interface on nw-c1-m1.
#
# Run on: nw-c1-m1

IFACE=${3:-ens3}

echo "=== $IFACE ==="
sudo tc qdisc show dev $IFACE
