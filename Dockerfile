FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    ca-certificates \
    curl \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vagrant \
 && echo "vagrant:vagrant" | chpasswd \
 && usermod -aG sudo vagrant \
 && echo "vagrant ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vagrant \
 && chmod 0440 /etc/sudoers.d/vagrant

RUN mkdir -p /var/run/sshd \
 && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
