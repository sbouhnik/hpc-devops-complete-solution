/usr/local/bin/slurm_metrics_job.sh:
  file.managed:
    - source: salt://jobs/slurm_metrics_job.sh
    - mode: '0755'

cron_pkg:
  pkg.installed:
    - name: cron

cron_service:
  service.running:
    - name: cron
    - enable: True
    - require:
      - pkg: cron_pkg

slurm_metrics_cron:
  cron.present:
    - name: sbatch /usr/local/bin/slurm_metrics_job.sh
    - user: root
    - minute: '*/5'
    - require:
      - service: cron_service
