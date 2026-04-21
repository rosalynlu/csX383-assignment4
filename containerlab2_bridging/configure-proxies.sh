#!/usr/bin/env bash
set -euo pipefail

LAB=clab-pa3bridges

echo "Configuring socat proxies for bridge HIL..."

# c2edge: listen on bridge IP, forward to C2 inventory
docker exec -d ${LAB}-c2edge socat TCP-LISTEN:30081,fork,reuseaddr TCP:172.16.2.99:30081
docker exec -d ${LAB}-c2edge socat TCP-LISTEN:30557,fork,reuseaddr TCP:172.16.2.99:30557
echo "  c2edge: gRPC+ZMQ -> 172.16.2.99"

# c4edge: listen on bridge IP, forward to C4 inventory (backup cluster)
docker exec -d ${LAB}-c4edge socat TCP-LISTEN:30081,fork,reuseaddr TCP:172.16.4.151:31081
docker exec -d ${LAB}-c4edge socat TCP-LISTEN:30557,fork,reuseaddr TCP:172.16.4.151:31557
echo "  c4edge: gRPC+ZMQ -> 172.16.4.151"

# each proxy: two paths through the bridge
#   C2 path — ports 30081/30557 forward to c2edge (primary)
#   C4 path — ports 30181/30657 forward to c4edge (backup)
for proxy in breadproxy dairyproxy meatproxy produceproxy partyproxy; do
  docker exec -d ${LAB}-${proxy} socat TCP-LISTEN:30081,fork,reuseaddr TCP:192.168.50.10:30081
  docker exec -d ${LAB}-${proxy} socat TCP-LISTEN:30557,fork,reuseaddr TCP:192.168.50.10:30557
  docker exec -d ${LAB}-${proxy} socat TCP-LISTEN:30181,fork,reuseaddr TCP:192.168.50.11:30081
  docker exec -d ${LAB}-${proxy} socat TCP-LISTEN:30657,fork,reuseaddr TCP:192.168.50.11:30557
  echo "  ${proxy}: C2 path -> c2edge (192.168.50.10)  C4 path -> c4edge (192.168.50.11)"
done

echo ""
echo "Done. Now run expose-proxies.sh ON team-ras-1 to expose ports to K8s:"
echo "  ssh team-ras-1 'bash ~/expose-proxies.sh'"
