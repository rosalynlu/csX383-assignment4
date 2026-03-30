#!/usr/bin/env bash
# Run this ON team-ras-1 to expose clab proxy containers to K8s Cluster 3.
# Each proxy gets its own host port so each robot traverses a different bridge path.
# Container management IPs are resolved dynamically so this survives redeployments.
#
# Port mapping (team-ras-1 172.16.6.164):
#   breadproxy   gRPC=31081  ZMQ=31557
#   dairyproxy   gRPC=31082  ZMQ=31558
#   meatproxy    gRPC=31083  ZMQ=31559
#   produceproxy gRPC=31084  ZMQ=31560
#   partyproxy   gRPC=31085  ZMQ=31561

set -euo pipefail

LAB=clab-pa3bridges

# Kill any previous expose-proxies socat processes
pkill -f "socat TCP-LISTEN:310[0-9][0-9]" 2>/dev/null || true
pkill -f "socat TCP-LISTEN:315[0-9][0-9]" 2>/dev/null || true
sleep 1

declare -A GRPC_PORTS=(
  [breadproxy]=31081
  [dairyproxy]=31082
  [meatproxy]=31083
  [produceproxy]=31084
  [partyproxy]=31085
)

declare -A ZMQ_PORTS=(
  [breadproxy]=31557
  [dairyproxy]=31558
  [meatproxy]=31559
  [produceproxy]=31560
  [partyproxy]=31561
)

for proxy in breadproxy dairyproxy meatproxy produceproxy partyproxy; do
  ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${LAB}-${proxy})
  grpc=${GRPC_PORTS[$proxy]}
  zmq=${ZMQ_PORTS[$proxy]}

  nohup socat TCP-LISTEN:${grpc},fork,reuseaddr TCP:${ip}:30081 >/tmp/socat-${proxy}-grpc.log 2>&1 &
  nohup socat TCP-LISTEN:${zmq},fork,reuseaddr  TCP:${ip}:30557 >/tmp/socat-${proxy}-zmq.log  2>&1 &
  echo "  ${proxy} (${ip}): 172.16.6.164:${grpc} (gRPC)  172.16.6.164:${zmq} (ZMQ)"
done

echo ""
echo "All proxy ports live on 172.16.6.164."
