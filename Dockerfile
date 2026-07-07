FROM ubuntu:22.04

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    dbus \
    sudo \
    openssh-server \
    ca-certificates \
    curl \
    iproute2 \
    net-tools \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vagrant \
 && echo "vagrant:vagrant" | chpasswd \
 && usermod -aG sudo vagrant \
 && passwd -u vagrant \
 && chage -E -1 vagrant \
 && chage -I -1 vagrant \
 && echo "vagrant ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vagrant \
 && chmod 0440 /etc/sudoers.d/vagrant

RUN mkdir -p /run/sshd \
 && ssh-keygen -A \
 && sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?KbdInteractiveAuthentication .*/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config \
 && sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN mkdir -p /etc/systemd/system/ssh.service.d \
 && printf '%s\n' \
    '[Service]' \
    'ExecStartPre=' \
    'ExecStartPre=/bin/mkdir -p /run/sshd' \
    'ExecStartPre=/bin/rm -f /run/nologin /etc/nologin' \
    > /etc/systemd/system/ssh.service.d/override.conf 

RUN systemctl enable ssh \
 && systemctl set-default multi-user.target

RUN apt-get update && apt-get install -y locales \
 && locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

RUN systemctl mask \
    dev-hugepages.mount \
    sys-fs-fuse-connections.mount \
    sys-kernel-config.mount \
    display-manager.service \
    getty@.service \
    systemd-logind.service \
    systemd-remount-fs.service \
    getty.target \
    graphical.target

RUN apt-get update && apt-get install -y dbus \
 && systemctl enable dbus.service \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 22

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]