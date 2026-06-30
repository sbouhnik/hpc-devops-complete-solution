# HPC-DevOps Hybrid Orchestrator

This project builds a small, reproducible HPC DevOps lab around Slurm, SaltStack,
K3s, Prometheus, Grafana, and a custom Slurm metrics gateway.

It is designed as an assignment-ready implementation skeleton: one VM builds the
artifacts, one VM runs the Slurm control plane and accounting services, and one VM
runs the compute worker plus the Kubernetes-based monitoring stack.

## Architecture

| Node | IP | Main responsibilities |
|---|---:|---|
| `builder` | `192.168.56.10` | Builds Slurm DEB artifacts and the metrics gateway container image |
| `controller` | `192.168.56.11` | Salt master/minion, Slurm controller, SlurmDBD, MariaDB, Munge, node-exporter |
| `compute` | `192.168.56.12` | Salt minion, Slurm worker, K3s, Helm, Prometheus, Grafana, metrics gateway, demo cron job |

## Repository Layout

```text
.
|-- artifacts/
|   |-- debs/                 # Built Slurm packages
|   `-- images/               # Built metrics gateway image tarball
|-- builder/
|   `-- bootstrap_builder.sh  # Builder VM bootstrap script
|-- gateway/
|   |-- app.py                # Flask metrics gateway
|   |-- Dockerfile
|   `-- requirements.txt
|-- helm/
|   `-- metrics-gateway/      # Source Helm chart copy
|-- pillar/
|   |-- secrets.sls           # Demo-only secrets
|   |-- slurm.sls             # Cluster, Slurm, and gateway settings
|   `-- top.sls
|-- salt/
|   |-- common/
|   |-- cron/
|   |-- grafana/
|   |-- helm/metrics-gateway/ # Salt-deployed Helm chart copy
|   |-- jobs/
|   |-- k3s/
|   |-- mariadb/
|   |-- munge/
|   |-- node_exporter/
|   |-- podman/
|   |-- slurm/
|   `-- top.sls
|-- README.md
`-- Vagrantfile
```

## What Gets Provisioned

The Vagrant environment provisions:

- Salt master and minions
- Munge authentication for Slurm
- Slurm controller, SlurmDBD, Slurm worker, and client tooling
- MariaDB for Slurm accounting
- Node exporter on the controller
- K3s and Helm on the compute node
- kube-prometheus-stack with Grafana ingress at `grafana.local`
- A custom Flask metrics gateway deployed with Helm
- A demo Slurm job submitted by cron every five minutes
- A Grafana dashboard for live Slurm job load metrics

## Quick Start

Start the builder first so Slurm packages and the gateway image are available:

```bash
vagrant up builder
```

Start the controller and compute nodes:

```bash
vagrant up controller 
vagrant up compute
```

Accept Salt keys and apply the Salt states:

```bash
vagrant ssh controller -c "sudo salt-key -a compute -y"
vagrant ssh compute -c "sudo salt-call state.highstate"
```

Add this entry to your host machine:

```text
192.168.56.12 grafana.local
```

Open Grafana:

```text
https://grafana.local
```

Demo credentials are stored in `pillar/secrets.sls`:

```text
admin / admin
```

These credentials are for the lab only. Replace them before any real deployment.

## Metrics Flow

The compute node installs `/usr/local/bin/slurm_metrics_job.sh` and schedules it
with cron every five minutes.

The job:

- runs through Slurm with `sbatch`
- emits synthetic CPU, GPU, and memory load values
- attaches Slurm job and node labels
- sends values to the metrics gateway

Default gateway endpoint:

```text
http://192.168.56.12:30080/update-metric
```

Inside Kubernetes, Prometheus scrapes:

```text
metrics-gateway.default.svc.cluster.local:8080/metrics
```

Example update:

```bash
curl -X PUT http://metrics-gateway.default.svc.cluster.local:8080/update-metric \
  -H 'Content-Type: application/json' \
  -d '{"metric":"slurm_cpu_load","value":42,"labels":{"SLURM_JOB_ID":"123","SLURMD_NODENAME":"compute"}}'
```

Example Prometheus output:

```text
slurm_cpu_load{SLURM_JOB_ID="123",SLURMD_NODENAME="compute"} 42
```

Useful Grafana or Prometheus queries:

```promql
avg(slurm_cpu_load) by (SLURM_JOB_ID,SLURMD_NODENAME)
avg(slurm_gpu_load) by (SLURM_JOB_ID,SLURMD_NODENAME)
avg(slurm_mem_load) by (SLURM_JOB_ID,SLURMD_NODENAME)
```

## Current Scaling Limits

This repository is intentionally small, but the current implementation has some
important scaling limits:

- `salt/slurm/init.sls` hardcodes one Slurm compute node named `compute`.
- `pillar/slurm.sls` stores only one controller IP and one compute IP.
- `Vagrantfile` defines one fixed compute VM instead of generating compute nodes from inventory.
- The compute VM is configured with more virtual CPUs than Slurm currently advertises.
- Slurm controller, SlurmDBD, and MariaDB all run on the same VM.
- The metrics gateway stores all metrics in local process memory.
- `replicaCount` is `1` for the metrics gateway because local in-memory state is not shared.
- The demo metrics job uses high-cardinality job labels, which is acceptable for a lab but risky for a large Prometheus deployment.
- Salt accepts minion keys automatically during provisioning, which is convenient for a demo but not secure for production.

## Recommended Scalability Improvements

For a larger cluster, make these changes first:

1. Move Slurm node definitions into Pillar.

   Store node names, IPs, CPUs, memory, features, GRES/GPU settings, and partitions
   in `pillar/slurm.sls`, then render `NodeName` and `PartitionName` dynamically in
   `salt/slurm/init.sls`.

2. Generate compute VMs from inventory.

   Update `Vagrantfile` so compute nodes are created in a loop from a list or map.
   This makes it easy to test multiple workers locally.

3. Use role-based Salt targeting.

   Replace literal targets like `controller` and `compute` with role grains such as
   `role:controller`, `role:compute`, `role:monitoring`, and `role:database`.

4. Split the control plane.

   For production-like deployments, separate MariaDB, SlurmDBD, Slurm controller,
   login nodes, compute nodes, and monitoring services.

5. Add Slurm controller high availability.

   Add a backup controller, shared or replicated Slurm state, and a tested failover
   path.

6. Replace the demo metrics gateway with production exporters.

   Prefer node-exporter, Slurm exporters, DCGM exporter for GPUs, and accounting data
   from SlurmDBD. If a push gateway is still needed, use durable/shared storage and
   avoid local-only process memory.

7. Control Prometheus label cardinality.

   Be careful with labels such as job ID, user, command, and allocation ID. They can
   grow quickly and increase Prometheus memory and storage usage.

8. Secure secrets and access.

   Replace demo secrets, disable automatic Salt key acceptance, rotate Munge keys
   safely, add TLS, and avoid default Grafana credentials.

## Recommended Version Updates

The most important version improvement is to pin supported versions instead of using
floating install scripts and unpinned repositories.

Recommended direction:

- Salt: pin to the current LTS release instead of using an unpinned `stable` repo.
- Ubuntu: move from `ubuntu/jammy64` to a newer LTS base once package compatibility is tested.
- K3s: pin a known-good K3s release instead of using `curl -sfL https://get.k3s.io | sh`.
- Helm: pin a known-good Helm release instead of installing from the live main branch script.
- kube-prometheus-stack: pin the chart version used for Grafana and Prometheus.
- Slurm: prefer a stable Slurm release for cluster use; avoid release-candidate packages for production-like testing.

## Production Notes

Before using this outside a local lab:

- Replace all demo secrets in `pillar/secrets.sls`.
- Pin package, chart, container, and OS versions.
- Add TLS certificates for Grafana ingress.
- Add backups for MariaDB and Slurm accounting data.
- Tune MariaDB for SlurmDBD load.
- Add monitoring for SlurmDBD, Slurm controller health, queue depth, node states, and failed jobs.
- Validate Slurm package names and dependencies against the exact Ubuntu release in use.
- Replace synthetic demo metrics with real node, job, and GPU metrics.
- Add CI checks for Salt rendering and Helm chart templates.

## Validation Checklist

After provisioning, validate:

```bash
vagrant ssh controller -c "sudo salt '*' test.ping"
vagrant ssh controller -c "sinfo"
vagrant ssh controller -c "sacctmgr show cluster"
vagrant ssh compute -c "sudo kubectl get pods -A"
vagrant ssh compute -c "curl -s http://127.0.0.1:30080/metrics"
```

Then open Grafana at:

```text
https://grafana.local
```

The live Slurm dashboard should show the synthetic CPU, GPU, and memory load
reported by the scheduled Slurm job.
