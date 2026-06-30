{% set node_id = grains['id'] %}

slurm-group:
  group.present:
    - name: slurm
    - system: True

slurm-user:
  user.present:
    - name: slurm
    - system: True
    - gid: slurm
    - home: /var/lib/slurm
    - shell: /usr/sbin/nologin
    - createhome: False
    - require:
      - group: slurm-group

install_slurm_debs:
  cmd.run:
    - name: |
        export DEBIAN_FRONTEND=noninteractive
        set -e
        if ls /vagrant/artifacts/debs/*.deb >/dev/null 2>&1; then
          apt-get update
          apt-get install -y /vagrant/artifacts/debs/*.deb || apt-get -f install -y
        else
          apt-get install -y slurm-wlm slurmdbd || true
        fi
        apt-get install -y libpmix2
    - creates: /usr/sbin/slurmd

/etc/slurm/slurm.conf:
  file.managed:
    - makedirs: True
    - mode: '0600'
    - user: slurm
    - group: slurm
    - contents: |
        ClusterName={{ pillar['cluster']['name'] }}
        SlurmctldHost={{ pillar['cluster']['controller'] }}({{ pillar['cluster']['controller_ip'] }})
        MpiDefault=none
        ProctrackType=proctrack/linuxproc
        ReturnToService=2
        SlurmctldPidFile=/run/slurmctld.pid
        SlurmdPidFile=/run/slurmd.pid
        SlurmdSpoolDir=/var/spool/slurmd
        SlurmUser=slurm
        StateSaveLocation=/var/spool/slurmctld
        SwitchType=switch/none
        TaskPlugin=task/none
        AccountingStorageType=accounting_storage/slurmdbd
        AccountingStorageHost=controller
        NodeName={{ node_id }} NodeAddr={{ pillar['cluster'][node_id ~ '_ip'] }} CPUs=6 RealMemory=3000 State=UNKNOWN
        PartitionName=debug Nodes={{ node_id }} Default=YES MaxTime=INFINITE State=UP

{% if grains['id'] == 'controller' %}
/etc/slurm/slurmdbd.conf:
  file.managed:
    - mode: '0600'
    - user: slurm
    - group: slurm
    - makedirs: True
    - contents: |
        AuthType=auth/munge
        DbdHost=controller
        SlurmUser=slurm
        StorageType=accounting_storage/mysql
        StorageHost=localhost
        StorageUser={{ pillar['slurm']['db_user'] }}
        StoragePass={{ pillar['slurm']['db_password'] }}
        StorageLoc={{ pillar['slurm']['db_name'] }}

slurmctld_spool:
  file.directory:
    - name: /var/spool/slurmctld
    - user: slurm
    - group: slurm
    - makedirs: True

slurmdbd_service:
  service.running:
    - name: slurmdbd
    - enable: True
    - watch:
      - file: /etc/slurm/slurmdbd.conf

slurmctld_service:
  service.running:
    - name: slurmctld
    - enable: True
    - watch:
      - file: /etc/slurm/slurm.conf

slurmd_disabled:
  service.dead:
    - name: slurmd
    - enable: False

{% endif %}

{% if grains['id'] == 'compute' %}
slurmd_spool:
  file.directory:
    - name: /var/spool/slurmd
    - user: slurm
    - group: slurm
    - makedirs: True

slurmd_service:
  service.running:
    - name: slurmd
    - enable: True
    - watch:
      - file: /etc/slurm/slurm.conf
{% endif %}
