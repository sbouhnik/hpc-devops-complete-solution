#!/usr/bin/env bash
#SBATCH --job-name=slurm-live-load
#SBATCH --partition=debug
#SBATCH --time=00:01:00
set -euo pipefail
GATEWAY_URL="${GATEWAY_URL:-http://192.168.56.12:30080/update-metric}"
JOB_ID="${SLURM_JOB_ID:-manual}"
NODE_NAME="${SLURMD_NODENAME:-$(hostname)}"
for i in $(seq 1 12); do
  cpu=$(( RANDOM % 100 ))
  gpu=$(( RANDOM % 100 ))
  mem=$(( RANDOM % 100 ))
  for metric in cpu gpu mem; do
    value_var="$metric"
    value="${!value_var}"
    curl -sS -X PUT "$GATEWAY_URL" -H 'Content-Type: application/json' \
      -d "{\"metric\":\"slurm_${metric}_load\",\"value\":${value},\"labels\":{\"SLURM_JOB_ID\":\"${JOB_ID}\",\"SLURMD_NODENAME\":\"${NODE_NAME}\"}}" >/dev/null
  done
  sleep 5
done
