# csX383-assignment4

This repository contains the implementation of Programming Assignment 4 for CSX383 using a microservice architecture, which is based off of [Programming Assignment 1](https://github.com/rosalynlu/csX383-assignment1), [Programming Assignment 2](https://github.com/rosalynlu/csX383-assignment2), and [Programming Assignment 3](https://github.com/rosalynlu/csX383-assignment3).

## Table of Contents
* [**Programming Assignment 1**](#Programming-Assignment-1)
  * [Architecture Overview](#Architecture-Overview)
  * [Technologies Used](#Technologies-Used)
  * [Setup](#Setup)
  * [Deployment](#Deployment)
  * [Latency Analytics](#Latency-Analytics)
* [**Programming Assignment 2**](#Programming-Assignment-2)
  * [Locust Workload & Tail Latency Analysis](#Locust-Workload-&-Tail-Latency-Analysis)
  * [ContainerLab HIL Implementation](#ContainerLab-HIL-Implementation)
* [**Programming Assignment 3**](#Programming-Assignment-3)
  * [ContainerLab OSPF WAN](#ContainerLab-OSPF-WAN)
  * [ContainerLab2 Bridging Topology](#ContainerLab2-Bridging-Topology)
  * [Deployment](#Deployment)
  * [Collecting Outputs and Cleanup](#Collecting-Outputs-and-Cleanup)
  * [Cleanup](#Cleanup)
* [Notes](#Notes)

## Repository Structure

```
csX383-assignment3/
├── client/
│   ├── __init__.py
│   └── requirements.txt         # Python dependencies (all services)
├── containerlab1_ospf/          # OSPF WAN topology
│   ├── clab-pa3wan/             # Auto-generated runtime directory
│   │   └── ...
│   ├── outputs/                 # Outputs
│   │   └── ...
│   ├── r1-r6/                   # Router configs (FRR)
│   ├── capture.sh               # Collect routing + OSPF outputs
│   ├── cleanup.sh               # Destroy topology
│   ├── pa3wan.clab.yaml         # ContainerLab topology (6 routers + 2 LAN hosts)
│   ├── run.sh                   # Deploy topology + configure LAN interfaces
│   └── set-lan-ifs.sh           # Configure LAN1/LAN2 host interfaces
├── data/
│   ├── ...                      # Latencies datasets
├── flatbuffers_local/
│   ├── __init__.py
│   └── work.fbs                 # Local FlatBuffers schema backup
├── generated/
│   ├── flatbuffers/
│   │   └── __init__.py          # FlatBuffers generated Python modules
│   ├── proto/
│   │   ├── __init__.py
│   │   ├── grocery_pb2.py       # Generated Protobuf Python code
│   │   └── grocery_pb2_grpc.py  # Generated gRPC Python stubs
│   └── __init__.py
├── groceryfb/
│   ├── __init__.py
│   ├── ItemQty.py               # Generated FlatBuffers classes
│   ├── RequestType.py
│   └── WorkOrder.py
├── inventory/
│   ├── Dockerfile
│   └── requirements.txt
├── k8s/                         # Kubernetes
│   └── ...
├── ordering/
│   ├── Dockerfile
│   └── requirements.txt
├── out/                         # CDF/Latency statistics outputs
│   └── ...
├── pricing/
│   ├── Dockerfile
│   └── requirements.txt
├── robot/
│   ├── Dockerfile
│   └── requirements.txt
├── schemas/
│   ├── flatbuffers/
│   │   └── work.fbs             # FlatBuffers schema (Inventory -> Robots)
│   ├── proto/
│   │   ├── grocery.proto        # Protobuf schema (all gRPC services)
│   │   └── robots.proto         # Robot-specific Protobuf definitions
│   └── sql/
│       ├── init_schema.sql      # PostgreSQL database schema
│       └── seed_data.sql        # Initial data for items and pricing
├── scripts/
│   ├── init_db.sh               # Database initialization script
│   ├── locustfile.py            # Locust worload definition for load testing
│   ├── plot_latency.py          # latency analytics visualization script
│   ├── requirements.txt
│   └── tail_latency.py          # P2 tail lantency analysis(P50/P90/P95 + CDF) 
├── services/
│   ├── client_streamlit/
│   │   ├── Dockerfile
│   │   ├── app.py               # Streamlit web UI client
│   │   └── requirements.txt
│   ├── inventory_grpc/
│   │   ├── __init__.py
│   │   └── server.py            # Inventory gRPC server + ZeroMQ PUB
│   ├── ordering_flask/
│   │   └── app.py               # Flask Ordering service (HTTP/JSON -> gRPC)
│   ├── pricing_grpc/
│   │   ├── __init__.py
│   │   └── server.py            # Pricing gRPC server
│   └── robots/
│       └── robot.py             # Robot worker (run 5 instances with different names)
├── utils/
│   ├── __init__.py
│   └── db.py                    # Database connection helper
├── .dockerignore
├── .env                         # Environment variables (not in git)
├── .env.example                 # Example environment configuration
├── .gitignore
├── DOCKER_README.md
├── MILESTONE1_MULTICLUSTER_README.md
├── README.md                    # This file
└── build-all-sh
```

# Programming Assignment 1

## Architecture Overview

- **Streamlit** web interface client
- **Flask + HTTP/JSON** ordering microservice
- **gRPC + Protobuf** inventory microservice
- **gRPC + Protobuf** pricing microservice
- **PostgreSQL** database (inventory, pricing, analytics)
- **ZeroMQ pub-sub + FlatBuffers** payload for robot communication
  - Inventory publishes FETCH/RESTOCK topics via FlatBuffers payload
  - Robots subscribe and respond back to inventory via gRPC/Protobuf

## Technologies Used

- **Frontend**: Streamlit web UI
- **Ordering Service**: Flask + HTTP/JSON → gRPC
- **Inventory Service**: gRPC + Protobuf server, ZeroMQ PUB publisher
- **Pricing Service**: gRPC + Protobuf server
- **Robot Communication**:
  - Inventory → Robots: ZeroMQ PUB/SUB + FlatBuffers
  - Robots → Inventory: gRPC + Protobuf
- **Database**: PostgreSQL (inventory, pricing, analytics)
- **Deployment Environment**: Chameleon Cloud VM (Ubuntu 24.04)
- **Access Method**: SSH with port forwarding (tunneling)

## Setup

### Requirements

SSH into the VM from your local machine (using your SSH config + bastion setup)

From the repository root, activate the virtual environment:

```
source .venv/bin/activate
```

Install required packages:

```bash
pip install -r client/requirements.txt
```

Install FlatBuffers compiler (flatc):

```bash
sudo apt update
sudo apt install -y flatbuffers-compiler
flatc --version
```

### Database Setup

The PostgreSQL database stores:
- **Items table**: Product inventory (name, category, quantity)
- **Pricing table**: Item pricing information
- **Analytics table**: Request tracking (request_id, served_id, request_type, duration metrics)

Install PostgreSQL:

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
```

Start PostgreSQL service:

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

Create database user and set password (skip this step if already created):

```bash
sudo -u postgres createuser -s --pwprompt admin
```

Copy environment configuration:

```bash
cp .env.example .env
```

Edit the .env file and set your database password:

```bash
nano .env
```

Update the following variables:
- `DB_PASSWORD`: The password you set for your PostgreSQL user
- `DB_USER`: Database user (default: admin)
- `DB_NAME`: Database name (default: grocery_db)
- `DB_HOST`: Database host (default: localhost)
- `DB_PORT`: Database port (default: 5432)

Initialize database (creates tables and seeds initial data):

```bash
bash scripts/init_db.sh
```

This script will:
- Create the grocery_db database
- Create tables (items, pricing, analytics)
- Seed initial inventory data (9 items across 5 categories)
- Seed pricing data for all items

Expected output:

```bash
Database initialized and seeded
```

## Deployment

You will run Inventory, 5 robots, Pricing, Ordering, and Streamlit on the cloud VM.

### Install and start tmux

```bash
sudo apt install -y tmux
tmux new -s pa1
```

where `pa1` is the user-defined tmux session name.

Once inside tmux, create windows for each service. After each command, the terminal will hang (this is expected). To open a new window, `CTRL-B + C` or `CTRL-B + : + new-window`. The new window should already be in the repository root.

### Run

**Window 1 - Inventory (gRPC + ZeroMQ PUB)**

```bash
source .venv/bin/activate
python services/inventory_grpc/server.py
```

Expected output:

```bash
[Inventory] ZMQ PUB bound at tcp://0.0.0.0:5556
[Inventory gRPC] listening on 0.0.0.0:50051
```

**Windows 2-6 - Robots (5 separate processes)**

Run one command per window:

```bash
source .venv/bin/activate
python services/robots/robot.py --name bread
```

```bash
source .venv/bin/activate
python services/robots/robot.py --name dairy
```

```bash
source .venv/bin/activate
python services/robots/robot.py --name meat
```

```bash
source .venv/bin/activate
python services/robots/robot.py --name produce
```

```bash
source .venv/bin/activate
python services/robots/robot.py --name party
```

Expected outputs:

```bash
[bread] Connected SUB to tcp://127.0.0.1:5556 (topics: FETCH, RESTOCK)
[bread] gRPC connected to Inventory at 127.0.0.1:50051
```

```bash
[dairy] Connected SUB to tcp://127.0.0.1:5556 (topics: FETCH, RESTOCK)
[dairy] gRPC connected to Inventory at 127.0.0.1:50051
```

```bash
[meat] Connected SUB to tcp://127.0.0.1:5556 (topics: FETCH, RESTOCK)
[meat] gRPC connected to Inventory at 127.0.0.1:50051
```

```bash
[produce] Connected SUB to tcp://127.0.0.1:5556 (topics: FETCH, RESTOCK)
[produce] gRPC connected to Inventory at 127.0.0.1:50051
```

```bash
[party] Connected SUB to tcp://127.0.0.1:5556 (topics: FETCH, RESTOCK)
[party] gRPC connected to Inventory at 127.0.0.1:50051
```

**Window 7 - Pricing (gRPC)**

```bash
source .venv/bin/activate
python services/pricing_grpc/server.py
```

Expected output:

```bash
[Pricing gRPC] listening on 0.0.0.0:50053
```

**Window 8 - Ordering (Flask)**

```bash
source .venv/bin/activate
export INVENTORY_ADDR=127.0.0.1:50051
export FLASK_APP=services/ordering_flask/app.py
flask run --host 0.0.0.0 --port 5000
```

Expected output:

```bash
 * Serving Flask app 'services/ordering_flask/app.py'
 * Debug mode: off
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://172.16.6.226:5000
Press CTRL+C to quit
```

**Window 9 - Streamlit Client**

```bash
source .venv/bin/activate
streamlit run services/client_streamlit/app.py --server.address 0.0.0.0 --server.port 8501
```

Expected output:

```bash
Collecting usage statistics. To deactivate, set browser.gatherUsageStats to false.


  You can now view your Streamlit app in your browser.

  URL: http://0.0.0.0:8501
```

### Detach tmux

To leave tmux running, `CTRL-B + D`.

To reattach later:

```bash
tmux attach -t pa1
```

where `pa1` is the same user-defined tmux session name as when it was created.

**Open in browser**

Streamlit UI:

http://localhost:8501

Ordering health check:

http://localhost:5000/health

### Using the Client

1. Open http://localhost:8501 in your browser

2. Set Ordering Service URL to:
   ```
   http://localhost:5000/submit
   ```

3. Select request type (`GROCERY_ORDER` or `RESTOCK_ORDER`)

4. Enter Customer/Supplier ID

5. Add item quantities (>0) for items across different categories

6. Click Submit

7. View the response:
   - For **GROCERY_ORDER**: Returns itemized bill with pricing and total
   - For **RESTOCK_ORDER**: Returns confirmation of inventory restocked

**Example JSON payload:**

```json
{
  "request_type": "GROCERY_ORDER",
  "id": "abc123",
  "items": {
    "bread": 1,
    "milk": 1,
    "beef": 1,
    "apples": 2,
    "napkins": 1
  }
}
```

**Example Streamlit display:**

```
HTTP status: 200
```

**Example JSON response (Grocery Order):**

```json
{
  "code": "OK"
  "message":
  "OK: received all robot replies for 3a31108f-a986-40b8-8bde-2ea8043e1ddd\n\nITEMIZED BILL:\n\tapples: 2 x $2.99 = $5.98\n\tnapkins: 1 x $4.99 = $4.99\n\tbread: 1 x $3.99 = $3.99\n\tmilk: 1 x $4.50 = $4.50\n\tbeef: 1 x $12.99 = $12.99\nTOTAL: $32.45"
}
```

**Example JSON response (Restock Order):**

```json
{
  "code": "OK",
  "message": "OK: received all robot replies for 5b42119g-b997-51c9-9cef-3fb9154f2eee"
}
```

Inventory terminal logs will show that it:
- receives gRPC request
- publishes FETCH via ZeroMQ
- receives 5 robot gRPC responses (ROBOT_OK or ROBOT_NOOP)

Robot terminals will also log their received message and response.

**Example:**

```bash
[bread] Working on bread (sleep 0.50s)
[bread] OK sent request_id=3a31108f-a986-40b8-8bde-2ea8043e1ddd served_id=abc123 items=['bread']
```

```bash
[dairy] Working on milk (sleep 0.58s)
[dairy] OK sent request_id=3a31108f-a986-40b8-8bde-2ea8043e1ddd served_id=abc123 items=['milk']
```

```bash
[meat] Working on beef (sleep 0.46s)
[meat] OK sent request_id=3a31108f-a986-40b8-8bde-2ea8043e1ddd served_id=abc123 items=['beef']
```

```bash
[produce] Working on apples (sleep 0.33s)
[produce] OK sent request_id=3a31108f-a986-40b8-8bde-2ea8043e1ddd served_id=abc123 items=['apples']
```

```bash
[party] Working on napkins (sleep 0.52s)
[party] OK sent request_id=3a31108f-a986-40b8-8bde-2ea8043e1ddd served_id=abc123 items=['napkins']
```

```bash
127.0.0.1 - - [06/Feb/2026 01:02:59] "POST /submit HTTP/1.1" 200 -
```

## Latency Analytics

Added a latency analytics visualization pipeline using PostgreSQL analytics data.

**Functionality:**
- Queries latency data from the PostgreSQL analytics table
- Generates latency histogram and boxplot visualizations
- Outputs summary statistics for latency performance

**Prerequisites:**
- PostgreSQL running
- Database initialized (`scripts/init_db.sh`)
- Services running (inventory, pricing, ordering, robots)
- Latency data generated by submitting orders through Streamlit

**Generate Latency Data**
1. Start all services
2. Open Streamlit UI
3. Submit approximately 20-50 orders

**Running**

From repository root:

```bash
cd ~/csX383-assignment1
source .venv/bin/activate
export $(grep -v '^#' .env | xargs)
python scripts/plot_latency.py
```

To run the script from your local machine instead of the VM, forward port 5432 (see the updated SSH command in [Notes](#notes)).

**Output:**
- `latency_histogram.png`
- `latency_boxplot.png`
- `latency_summary.txt`

If no latency data exists, the script will print `No latency data found in analytics table.`

# Programming Assignment 2

## Locust Workload & Tail Latency Analysis

### Running Locust Experiments
For local testing: 
Start all services (see Deployment section), then run from the project root:
```bash
source venv/bin/activate

# 1 concurrent user (3 reps)
RUN_TAG=u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://localhost:5000 2>/dev/null

# 10 concurrent users (3 reps)
RUN_TAG=u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://localhost:5000 2>/dev/null

# 20 concurrent users (3 reps)
RUN_TAG=u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://localhost:5000 2>/dev/null
RUN_TAG=u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://localhost:5000 2>/dev/null
```

Output CSVs are saved to `data/latencies_<RUN_TAG>.csv`. Workload is 85% refrigerator (GROCERY_ORDER) and 15% truck (RESTOCK_ORDER).

For testing on VM, ssh into nw-c1-m1, cd into csX383-assignment2, and run the following:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r scripts/requirements.txt

# Same commands as above, but with the VM's internal IP address for the host

# 1 concurrent user
RUN_TAG=u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null

# 10 concurrent users
RUN_TAG=u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null

# 20 concurrent users
RUN_TAG=u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
RUN_TAG=u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.136:30083 2>/dev/null
```

### Computing Tail Latencies & CDF Plots
```bash
python3 scripts/tail_latency.py \
  --input data/latencies_u1_rep*.csv data/latencies_u10_rep*.csv data/latencies_u20_rep*.csv \
  --outdir out \
  --title "Latency CDF" \
  --combined \
  --prefix baseline
```

Use `--prefix` to tag all output files with a descriptive prefix (e.g. `baseline_`, `wan30ms_`). If omitted, files use their default names.

**Output** (with `--prefix baseline_`):
- `out/baseline__cdf_per_run_baseline.png` — CDF curve per run
- `out/baseline_cdf_combined_baseline.png` — all runs overlaid
- `out/baseline_per_run_tail_latencies_baseline.csv` — P50/P90/P95/P99 per run
- `out/baseline_pooled_tail_latencies_baseline.csv` — pooled tail latency statistics
- `out/baseline_summary_baseline.txt` — pooled statistics across all runs

## ContainerLab HIL Implementation

### Install ContainerLab and Docker

Run on a seperate VM used for network emulation.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

bash -c "$(curl -sL https://get.containerlab.dev)"
sudo usermod -aG docker $USER
newgrp docker
```

### Build WAN Forwarder Image

Run on ContainerLab VM.

If `wan_forwarder` directory does not exist yet:

```bash
mkdir -p wan_forwarder
```

```bash
cd wan_forwarder
cat > Dockerfile <<'EOF'
FROM alpine:3.20
RUN apk add --no-cache socat iproute2
CMD ["sh","-c","sleep infinity"]
EOF
docker build -t wan-forwarder:latest .
```

Create `topo.yaml`:

```yaml
name: pa2-wan
topology:
  nodes:
    wan_c1_c2:
      kind: linux
      image: wan-forwarder:latest
    wan_c2_c3:
      kind: linux
      image: wan-forwarder:latest
```

Deploy and verify topology:

```bash
sudo containerlab deploy -t topo.yaml
docker ps | grep pa2-wan
```

Inside the forwarders:

```bash
docker exec -it clab-pa2-wan-wan_c1_c2 sh -lc '
# forward WAN endpoint port 30083 -> real ordering nodeport
socat TCP-LISTEN:30083,fork,reuseaddr TCP:<CLUSTER_WORKER_NODE_IP>:30083 &
'
```

```bash
docker exec -it clab-pa2-wan-wan_c2_c3 sh -lc '
# gRPC
socat TCP-LISTEN:30081,fork,reuseaddr TCP:<CLUSTER_WORKER_NODE_IP>:30081 &
# ZMQ (still TCP)
socat TCP-LISTEN:30557,fork,reuseaddr TCP:<CLUSTER_WORKER_NODE_IP>:30557 &
'
```

Get WAN endpoint IPs:

We inserted ContainerLab WAN links in two places: between Cluster 1 and Cluster 2 (C1-C2), and between Cluster 2 and Cluster 3 (C2-C3).

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clab-pa2-wan-wan_c1_c2
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clab-pa2-wan-wan_c2_c3
```

Apply WAN scenarios:

```bash
# C1-C2
docker exec -it clab-pa2-wan-wan_c1_c2 sh -lc '
tc qdisc add dev eth0 root netem delay 30ms loss 1% 2>/dev/null || true
'
# C2-C3
docker exec -it clab-pa2-wan-wan_c2_c3 sh -lc '
tc qdisc add dev eth0 root netem delay 30ms loss 1% 2>/dev/null || true
'
```

```bash
docker exec -it clab-pa2-wan-wan_c1_c2 sh -lc '
tc qdisc replace dev eth0 root netem delay 80ms loss 0.5%
tc qdisc add dev eth0 parent 1:1 tbf rate 10mbit burst 32kbit latency 400ms 2>/dev/null || true
'
# (if tbf layering is annoying, keep it simple and just do delay/loss)
```

```bash
docker exec -it clab-pa2-wan-wan_c1_c2 sh -lc 'tc qdisc del dev eth0 root 2>/dev/null || true'
docker exec -it clab-pa2-wan-wan_c2_c3 sh -lc 'tc qdisc del dev eth0 root 2>/dev/null || true'
```

### Point K8s Deployments

Run on local machine.

```bash
scp -r <VM_NAME>:~csX383-assignment2/k8s nw-c1-m1:~/team6
ssh nw-c1-m1 "kubectl apply -f team6/k8s/refrigerator-c1.yaml"
ssh nw-c3-m1 "kubectl apply -f team6/k8s/robots-c3.yaml"
```

Now all inter-cluster communication passes through ContainerLab WAN forwarders.

### Simulate WAN Network Conditions

```bash
docker exec clab-pa2-wan-wan_c1_c2 tc qdisc add dev eth0 root netem delay 30ms loss 1%

docker exec clab-pa2-wan-wan_c2_c3 tc qdisc add dev eth0 root netem delay 30ms loss 1%
```

```bash
docker exec clab-pa2-wan-wan_c1_c2 tc qdisc replace dev eth0 root netem delay 80ms loss 0.5%

docker exec clab-pa2-wan-wan_c2_c3 tc qdisc replace dev eth0 root netem delay 80ms loss 0.5%
```

```bash
docker exec clab-pa2-wan-wan_c1_c2 tc qdisc del dev eth0 root

docker exec clab-pa2-wan-wan_c2_c3 tc qdisc del dev eth0 root
```

### Run Workload Experiments

Repeat locust experiments for each WAN scenario and user load from the repo root:

```bash
python3 -m venv venv
source venv/bin/activate
```

```bash
RUN_TAG=baseline_u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://<NODE_IP>:30083
RUN_TAG=baseline_u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 2 --run-time 60s --host http://<NODE_IP>:30083
RUN_TAG=baseline_u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 3 --run-time 60s --host http://<NODE_IP>:30083
```

```bash
RUN_TAG=baseline_u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=baseline_u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=baseline_u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=baseline_u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=baseline_u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=baseline_u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan30ms_u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan30ms_u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan30ms_u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan30ms_u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan80ms_u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan80ms_u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

```bash
RUN_TAG=wan80ms_u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 1 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 2 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
RUN_TAG=wan80ms_u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 3 --run-time 60s --host http://<NODE_IP>:30083 2>/dev/null
```

`REFRIGERATOR_NODE_IP`: `172.20.20.2`

`ROBOTS_NODE_IP`: `172.20.20.3`

### Generate Tail Latency and CDF Plots

```bash
python3 scripts/tail_latency.py \
  --input "data/latencies_baseline_u*_rep*.csv" \
  --outdir out \
  --title "Baseline" \
  --combined \
  --prefix baseline_
```

```bash
python3 scripts/tail_latency.py \
  --input "data/latencies_wan30ms_u*_rep*.csv" \
  --outdir out \
  --title "WAN 30ms + 1% loss" \
  --combined \
  --prefix wan30ms_
```

```bash
python3 scripts/tail_latency.py \
  --input "data/latencies_wan80ms_u*_rep*.csv" \
  --outdir out \
  --title "WAN 80ms + 0.5% loss" \
  --combined \
  --prefix wan80ms_
```

Metrics generated:
- P50 latency
- P90 latency
- P95 latency
- P99 latency

CDF plots and CSV/text summaries are stored in `out/`, each suffixed with the `--prefix` value.

# Programming Assignment 3

## ContainerLab OSPF WAN

This replaces the original ContainerLab WAN forwarder with a 6-router OSPF-based WAN topology using FRRouting (FRR).

- Traffic enters through LAN1
- Traverses the WAN using OSPF shortest path (cost-based)
- Exits through LAN2
- Demonstrates link-state routing (Dijkstra) behavior

### Setup and Run

- Start all routers (r1–r6)
- Start LAN hosts (lan1host, lan2host)
- Configure LAN interfaces and routing

From repository root, navigate to the ContainerLab directory and deploy the topology:

```bash
cd containerlab1_ospf
./run.sh
```

Verify containers are running:

```bash
docker ps | grep clab-pa3wan
```

Check OSPF neighbors and routing table:

```bash
docker exec -it clab-pa3wan-r1 vtysh -c "show ip ospf neighbor"
docker exec -it clab-pa3wan-r1 vtysh -c "show ip route"
```

Run traceroute:

```bash
docker exec -it clab-pa3wan-lan1host traceroute 172.16.2.2
```

Expected path:

```
lan1 -> r4 -> r1 -> r3 -> r5 -> r2 -> r6 -> lan2
```

### Collect Required Outputs

Run:

```bash
./capture.sh
```

Generates in containerlab1_ospf/outputs
- `show ip route`
- `show ip ospf neighbor`
- `show ip ospf database`
- traceroute output

### Packet Capture (Wireshark/tcpdump)

Run from local machine:

```bash
ssh <VM_NAME> "docker exec -i clab-pa3wan-r1 tcpdump -i eth1 -U -w -" | wireshark -k -i
```

Or save to file:

```bash
ssh <VM_NAME> "docker exec -i clab-pa3wan-r1 tcpdump -i eth1 -U -w -" > r1_eth1.pcap
```

Open .pcap in Wireshark

### Cleanup

Run:

```bash
./cleanup.sh
```
## ContainerLab2 Bridging Topology

### Overview

ContainerLab2 runs on **team-ras-1** (172.16.6.164) and acts as a Layer 2 HIL between
Cluster 2 (services) and Cluster 3 (robot pods). It uses 4 Linux bridges with STP to
compute a minimum spanning tree, and socat proxy chains to route robot traffic through
the bridge network.

**Traffic path:**
```
C3 robot pod → team-ras-1:3108x → proxy container → bridge network (STP) → c2edge → C2 inventory
```

Each robot has its own proxy node on a different LAN, so each traverses a different path
through the spanning tree.

### Topology

4 Linux bridges (fully interconnected, STP eliminates loops):
- **br1** — priority 4096 (STP root)
- **br2** — priority 8192
- **br3** — priority 12288
- **br4** — priority 16384

6 host containers on `192.168.50.0/24`:

| Container | IP | Role |
|---|---|---|
| c2edge | 192.168.50.10 | Exit point → C2 inventory |
| breadproxy | 192.168.50.21 | Proxy for bread robot |
| dairyproxy | 192.168.50.22 | Proxy for dairy robot |
| meatproxy | 192.168.50.23 | Proxy for meat robot |
| produceproxy | 192.168.50.24 | Proxy for produce robot |
| partyproxy | 192.168.50.25 | Proxy for party robot |

Port mapping on team-ras-1 (172.16.6.164):

| Robot | gRPC port | ZMQ port | Proxy |
|---|---|---|---|
| bread | 31081 | 31557 | breadproxy |
| dairy | 31082 | 31558 | dairyproxy |
| meat | 31083 | 31559 | meatproxy |
| produce | 31084 | 31560 | produceproxy |
| party | 31085 | 31561 | partyproxy |

## Deployment

All commands run **on team-ras-1** unless noted.

**Step 1 — Deploy the topology and configure bridges:**
```bash
cd ~/csX383-assignment3/containerlab2_bridging
sudo bash run.sh
```
This deploys the containers, configures STP with weighted path costs, assigns IPs on
`192.168.50.0/24`, and starts socat inside each proxy container:
- Each proxy listens on 30081/30557 and forwards to c2edge (192.168.50.10) via the bridge
- c2edge listens on 30081/30557 and forwards to C2 inventory (172.16.2.99)

**Step 2 — Expose proxy ports to K8s (run on team-ras-1 host):**
```bash
bash ~/expose-proxies.sh
```
Starts socat on the host forwarding each robot's port pair (31081–31085, 31557–31561)
to the corresponding proxy container's management IP (172.20.20.x). This makes the
proxy containers reachable from C3. Requires `socat` installed (`sudo apt-get install -y socat`).

**Step 3 — Deploy updated robot pods (run from local machine):**
```bash
# Copy updated yamls to cluster master
scp k8s/robot-{bread,dairy,meat,produce,party}-c3.yaml nw-c3-m1:~/team6/k8s/

# Apply on cluster
ssh nw-c3-m1 "kubectl apply -f ~/team6/k8s/robot-bread-c3.yaml \
  -f ~/team6/k8s/robot-dairy-c3.yaml \
  -f ~/team6/k8s/robot-meat-c3.yaml \
  -f ~/team6/k8s/robot-produce-c3.yaml \
  -f ~/team6/k8s/robot-party-c3.yaml"
```
Each robot's `INVENTORY_ADDR` and `ZMQ_SUB_ADDR` now point to team-ras-1 (172.16.6.164)
on their assigned port instead of directly to C2.

**Step 4 — Verify end-to-end:**
```bash
# Run from team-ras-1
curl -s -X POST http://172.16.2.99:30083/submit \
  -H "Content-Type: application/json" \
  -d '{"request_type":"GROCERY_ORDER","id":"test","items":{"bread":1,"milk":1}}'
```
Expected: `"code":"OK"` with `"received all robot replies"`.

## Collecting Outputs and Cleanup

### Collecting Outputs

Run from team-ras-1 to capture MAC tables, ARP tables, STP state, and connectivity:
```bash
cd ~/csX383-assignment3/containerlab2_bridging
bash capture.sh
```
Outputs saved to `containerlab2_bridging/outputs/`.

### Cleanup

```bash
# On team-ras-1
cd ~/csX383-assignment3/containerlab2_bridging
bash cleanup.sh
pkill -f "socat TCP-LISTEN:310" || true
pkill -f "socat TCP-LISTEN:315" || true
```

---

# Programming Assignment 4

## Milestone 1

### System Architecture

The application is deployed across four Kubernetes clusters:

| Cluster | Subnet | Role | Services |
|---------|--------|------|----------|
| **C1** | 172.16.1.x | Client | `refrigerator` (Streamlit) — NodePort 30091 |
| **C2** | 172.16.2.x | Primary | `ordering` (30083), `inventory` (30081/30557), `pricing`, `grocery-db` |
| **C3** | 172.16.3.x | Robots | `bread`, `dairy`, `meat`, `produce`, `party` |
| **C4** | 172.16.4.x | Backup | `ordering` (31083), `inventory` (31081/31557), `pricing`, `grocery-db` |

### End-to-End Data Flow

```
Client (C1)
    ↓  HTTP  (172.20.20.2:30083 via OSPF WAN containerlab)
Ordering (C2)
    ↓  gRPC
Inventory (C2)
    ↓  ZMQ PUB → socat chain → bridged LAN → c2edge
Robots (C3) — subscribe via team-ras-1 proxy ports
    ↓  gRPC response
Inventory (C2) → response back to Ordering → Client
```

Both C2 (primary) and C4 (backup) are wired into the bridged LAN via **c2edge** and **c4edge** respectively, so either cluster's inventory can reach the C3 robot cluster through the same proxy infrastructure.

### WAN Topologies

Two ContainerLab WAN topologies provide paths between clusters:
- **ContainerLab 1 (OSPF)**: C1 → WAN → C2 (primary path)
- **ContainerLab 2 (backup WAN)**: C1 → WAN → C4 (backup path, for Milestone 3 traffic steering)

### Bridged LAN

The Bridged LAN ContainerLab (PA3) runs on team-ras-1 and connects both C2 and C4 to the C3 robot cluster. See the [ContainerLab2 Bridging Topology](#ContainerLab2-Bridging-Topology) section for deployment details.

### Network Policies

Intra-cluster namespace policies restrict traffic to only required communication paths:

**Cluster 2:**
- `default-deny-ingress-c2.yaml` — deny all ingress by default
- `allow-team6-core-ingress.yaml` — allow traffic between core service pods
- `allow-external-to-inventory.yaml` — allow external ingress on inventory gRPC/ZMQ ports

**Cluster 3:**
- `default-deny-ingress-c3.yaml` — deny all ingress by default
- `allow-team6-robot-ingress.yaml` — allow traffic between robot pods

### Kubernetes Manifests

| Manifest | Cluster | Description |
|----------|---------|-------------|
| `k8s/refrigerator-c1.yaml` | C1 | Streamlit client |
| `k8s/ordering-c2.yaml` | C2 | Ordering service (primary) |
| `k8s/inventory-c2.yaml` | C2 | Inventory service (primary) |
| `k8s/pricing-c2.yaml` | C2 | Pricing service (primary) |
| `k8s/analytics-db.yaml` | C2 | PostgreSQL database (primary) |
| `k8s/robot-{bread,dairy,meat,produce,party}-c3.yaml` | C3 | Robot workers |
| `k8s/ordering-c4.yaml` | C4 | Ordering service (backup) |
| `k8s/inventory-c4.yaml` | C4 | Inventory service (backup) |
| `k8s/pricing-c4.yaml` | C4 | Pricing service (backup) |
| `k8s/grocery-db-c4.yaml` | C4 | PostgreSQL database (backup) |

### Milestone 1 Status

| Item | Status |
|------|--------|
| Primary services deployed on C2 | Done |
| Robot workers deployed on C3, connected to C2 via bridged LAN | Done |
| Backup services deployed on C4 | Done |
| C4 inventory wired into bridged LAN via c4edge | Done |
| Intra-cluster network policies applied (C2, C3) | Done |
| End-to-end primary path verified (C1 → C2 → C3 robots) | Done |

### Verification

**1. Check pod state on all clusters**

```bash
# C2: should show ordering, inventory, pricing, grocery-db (no robots)
ssh nw-c2-m1 "kubectl get pods -n team6"

# C3: should show 10 robot pods — 5 subscribed to C2, 5 subscribed to C4
#   robot-bread, robot-dairy, robot-meat, robot-produce, robot-party       (C2 path)
#   robot-bread-c4, robot-dairy-c4, robot-meat-c4, robot-produce-c4, robot-party-c4  (C4 path)
ssh nw-c3-m1 "kubectl get pods -n team6"

# C4: should show ordering, inventory, pricing, grocery-db (no robots)
ssh nw-c4-m1 "kubectl get pods -n team6"
```

**2. Verify bridged LAN topology (run on team-ras-1)**

```bash
# eth5 should appear — that is the c4edge link into br1
docker exec clab-pa3bridges-br1 bridge link show

# c2edge and c4edge should be on the same L2 segment
docker exec clab-pa3bridges-c2edge ping -c 2 192.168.50.11

# c4edge can reach the robot proxies
docker exec clab-pa3bridges-c4edge ping -c 2 192.168.50.21
```

**3. End-to-end order tests**

These must be run from **team-ras-1** (the `172.16.x.x` addresses are Chameleon Cloud private IPs, not reachable from your local machine).

Both commands should return `"code":"OK"` with an itemized bill covering all five robot categories (bread, dairy, meat, produce, party) and a total of $23.97.

```bash
# SSH into team-ras-1 first
ssh team-ras-1

# C2 primary path
curl --max-time 15 -X POST http://172.16.2.99:30083/submit \
  -H 'Content-Type: application/json' \
  -d '{"request_type":"GROCERY_ORDER","id":"test","items":{"bread":1,"milk":1,"chicken":1,"apples":1,"soda":1}}'

# C4 backup path
curl --max-time 15 -X POST http://172.16.4.205:31083/submit \
  -H 'Content-Type: application/json' \
  -d '{"request_type":"GROCERY_ORDER","id":"test","items":{"bread":1,"milk":1,"chicken":1,"apples":1,"soda":1}}'
```

## Milestone 2

### Overview

Milestone 2 introduces WAN latency impairments and measures how they degrade end-to-end tail latencies compared to a baseline.

**Three scenarios measured:**
| Scenario | netem | Tag prefix |
|----------|-------|------------|
| Baseline | none | `pa4_wan_baseline` |
| 30 ms + 1% loss | `delay 30ms loss 1%` | `pa4_wan30ms` |
| 80 ms + 0.5% loss | `delay 80ms loss 0.5%` | `pa4_wan80ms` |

Impairments are applied to **ens3** on nw-c1-m1, which is the outbound interface towards C2. This adds delay to all traffic leaving the client cluster, simulating WAN latency degradation. All steps below run on **nw-c1-m1** unless noted.

---

### Step 1 — Collect baseline (no netem)

Ensure no netem is applied, then sanity check connectivity:

```bash
cd ~/csX383-assignment4/containerlab1_ospf
./clear-netem.sh
./verify-netem.sh
# Expected: "qdisc noqueue" or "qdisc pfifo_fast" — no netem line

ping -c 5 172.16.2.99
# Expected: low RTT (~1–5 ms)
```

Run Locust:

```bash
cd ~/csX383-assignment4
source venv/bin/activate

# 1 concurrent user
RUN_TAG=pa4_wan_baseline_u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null

# 10 concurrent users
RUN_TAG=pa4_wan_baseline_u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null

# 20 concurrent users
RUN_TAG=pa4_wan_baseline_u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan_baseline_u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
```

Produces 9 files: `data/latencies_pa4_wan_baseline_u{1,10,20}_rep{1,2,3}.csv`.

### Step 2 — Apply 30 ms impairment and collect data

```bash
cd ~/csX383-assignment4/containerlab1_ospf
./apply-netem.sh 30ms 1%
./verify-netem.sh   # confirm: should show "netem delay 30ms loss 1%"

ping -c 5 172.16.2.99
# Expected: RTT ~30 ms
```

Run Locust:

```bash
cd ~/csX383-assignment4
source venv/bin/activate

# 1 concurrent user
RUN_TAG=pa4_wan30ms_u1_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u1_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u1_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 1 -r 1 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null

# 10 concurrent users
RUN_TAG=pa4_wan30ms_u10_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u10_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u10_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 10 -r 10 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null

# 20 concurrent users
RUN_TAG=pa4_wan30ms_u20_rep1 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u20_rep2 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
RUN_TAG=pa4_wan30ms_u20_rep3 LOCUST_LOG_DIR=data locust -f scripts/locustfile.py --headless -u 20 -r 20 --run-time 60s --host http://172.16.2.99:30083 2>/dev/null
```

Produces 9 files: `data/latencies_pa4_wan30ms_u{1,10,20}_rep{1,2,3}.csv`.

### Step 3 — Switch to 80 ms impairment and collect data

```bash
cd ~/csX383-assignment4/containerlab1_ospf
./apply-netem.sh 80ms 0.5%
./verify-netem.sh   # confirm: should show "netem delay 80ms loss 0.5%"

ping -c 5 172.16.2.99
# Expected: RTT ~80 ms
```

Re-run the same Locust matrix substituting `pa4_wan80ms` for `pa4_wan30ms` in all `RUN_TAG` values. Produces `data/latencies_pa4_wan80ms_u*_rep*.csv`.

### Step 4 — Remove impairments (cleanup)

```bash
cd ~/csX383-assignment4/containerlab1_ospf
./clear-netem.sh
./verify-netem.sh   # confirm: no netem line in output
```

### Step 5 — Analyse and compare

**Per-scenario tail latencies + CDF plots:**

```bash
python3 scripts/tail_latency.py \
  --input "data/latencies_pa4_wan_baseline_u*_rep*.csv" \
  --outdir out --title "PA4 WAN Baseline" --combined --prefix pa4_wan_baseline

python3 scripts/tail_latency.py \
  --input "data/latencies_pa4_wan30ms_u*_rep*.csv" \
  --outdir out --title "PA4 WAN 30ms+1%loss" --combined --prefix pa4_wan30ms

python3 scripts/tail_latency.py \
  --input "data/latencies_pa4_wan80ms_u*_rep*.csv" \
  --outdir out --title "PA4 WAN 80ms+0.5%loss" --combined --prefix pa4_wan80ms
```

**Side-by-side scenario comparison (overlaid CDF + table):**

```bash
python3 scripts/compare_scenarios.py \
  --scenarios "WAN Baseline" "WAN 30ms+1%loss" "WAN 80ms+0.5%loss" \
  --inputs "data/latencies_pa4_wan_baseline_u*_rep*.csv" \
           "data/latencies_pa4_wan30ms_u*_rep*.csv" \
           "data/latencies_pa4_wan80ms_u*_rep*.csv" \
  --outdir out \
  --title "PA4 Milestone 2: Baseline vs WAN Degradation"
```

**Outputs:**
- `out/comparison_cdf.png` — overlaid CDF curves for all three scenarios
- `out/comparison_table.csv` — P50/P90/P95/P99 side-by-side
- `out/pa4_wan_baseline__cdf_*.png`, `out/pa4_wan30ms__cdf_*.png`, `out/pa4_wan80ms__cdf_*.png` — per-scenario CDFs

## Milestone 3

### Overview

Milestone 3 uses a Kubernetes egress `NetworkPolicy` on Cluster 1 to steer client traffic away from the degraded primary path (C1 → C2) to the backup path (C1 → C4), and measures the resulting latency.

> **Note:** Per the professor's clarification, namespace enforcement is **intra-cluster only**.

### Network Policies on C1

| Policy | Type | Effect |
|--------|------|--------|
| `default-deny-ingress` | Ingress | Deny all ingress by default |
| `allow-refrigerator-ingress` | Ingress | Allow pod traffic on port 8501 |
| `steer-to-backup` | **Egress** | Block C2 (`172.16.2.0/24`), allow C4 (`172.16.4.0/24`) |

### Deployment

**Apply steering policy on nw-c1-m1:**

```bash
kubectl apply -f k8s/steer-to-backup-c1.yaml
kubectl get networkpolicy -n team6
```

**Verify from inside the pod:**

```bash
POD=refrigerator-85dc78c77d-hxlxt

# C2 should be blocked
kubectl exec -n team6 -it $POD -- python3 -c "
import urllib.request, json
try:
    data = json.dumps({'request_type':'GROCERY_ORDER','id':'test','items':{'bread':1}}).encode()
    req = urllib.request.Request('http://172.16.2.99:30083/submit', data=data, headers={'Content-Type':'application/json'})
    r = urllib.request.urlopen(req, timeout=5)
    print('C2 REACHABLE:', r.read().decode())
except Exception as e:
    print('C2 BLOCKED:', e)
"

# C4 should succeed
kubectl exec -n team6 -it $POD -- python3 -c "
import urllib.request, json
data = json.dumps({'request_type':'GROCERY_ORDER','id':'test','items':{'bread':1,'milk':1,'chicken':1,'apples':1,'soda':1}}).encode()
req = urllib.request.Request('http://172.16.4.205:31083/submit', data=data, headers={'Content-Type':'application/json'})
r = urllib.request.urlopen(req, timeout=15)
print('C4 REACHABLE:', r.read().decode())
"
```

### Collecting Latency Data

Run Locust on nw-c1-m1 targeting C4.

```bash
cd ~/team6/csX383-assignment4
source venv/bin/activate

for users in 1 10 20; do
  for rep in 1 2 3; do
    echo "Running u${users}_rep${rep}..."
    RUN_TAG=pa4_steered_u${users}_rep${rep} LOCUST_LOG_DIR=data \
      locust -f scripts/locustfile.py --headless \
      -u $users -r $users --run-time 60s \
      --host http://172.16.4.205:31083 2>/dev/null
  done
done
```

**Outputs:**
- `data/latencies_pa4_steered_u{1,10,20}_rep{1,2,3}.csv` — raw latency CSVs per run

### Generating Plots

Run on nw-c1-m1.

```bash
python3 scripts/tail_latency.py \
  --input "data/latencies_pa4_steered_u*_rep*.csv" \
  --outdir out --title "PA4 Steered to Backup (C4)" --combined --prefix pa4_steered

python3 scripts/compare_scenarios.py \
  --scenarios "Baseline" "WAN 30ms+1%loss" "Steered to Backup" \
  --inputs "data/latencies_pa4_wan_baseline_u*_rep*.csv" \
           "data/latencies_pa4_wan30ms_u*_rep*.csv" \
           "data/latencies_pa4_steered_u*_rep*.csv" \
  --outdir out \
  --title "PA4 Milestone 3: Traffic Steering Recovery"
```

**Outputs:**
- `out/pa4_steered_summary.txt` — P50/P90/P95/P99 summary for steered scenario
- `out/pa4_steered_cdf_combined.png` — CDF plot for steered scenario
- `out/comparison_cdf.png` — overlaid CDF curves for all three scenarios
- `out/comparison_table.csv` — P50/P90/P95/P99 side-by-side

### Cleanup

```bash
kubectl delete networkpolicy steer-to-backup -n team6
```

---

# Notes

**PostgreSQL authentication tip:** To avoid re-running the database user/password setup after each VM restart, you can set `pg_hba.conf` to use `trust` authentication for local connections. Then a simple `sudo systemctl restart postgresql` will bring the existing database back up without needing to recreate anything.

**Port forwarding:** To run on a floating IP on Chameleon Cloud, on a separate terminal on your local machine (before opening in browser):

```bash
ssh -i ~/.ssh/VM-key.pem \
  -N -L 8501:127.0.0.1:8501 -L 5000:127.0.0.1:5000 -L 5432:127.0.0.1:5432 \
  cc@129.114.24.252
```

where `VM-key.pem` is the virtual machine key (`team-ras-ssh-keypair.pem`). Port 5432 is for running the analytics script locally against the VM's PostgreSQL database.

**Checking OSPF neighbors:** The warning `Can't open configuration file /etc/frr/vtysh.conf` is non-blocking and can be ignored.

**Bridged LAN restart:** After tearing down and redeploying the bridged LAN containerlab, robot pods on C3 must be restarted to re-establish their ZMQ connections:
```bash
ssh nw-c3-m1 "kubectl rollout restart deployment -n team6"
```
