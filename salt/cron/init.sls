/usr/local/bin/slurm_metrics_job.sh:
  file.managed:
    - source: salt://jobs/slurm_metrics_job.sh
    - mode: '0755'

slurm_metrics_cron:
  cron.present:
    - name: sbatch /usr/local/bin/slurm_metrics_job.sh
    - user: root
    - minute: '*/5'
