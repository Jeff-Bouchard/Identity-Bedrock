# Ness Attack Platform container (self-pentest box)
# Base: Debian stable with common PWK-style tools.
# Goal: lightweight but useful attacker environment you can run
# against your own Ness stack.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# Allow pip to modify the system environment inside this container build
# (PEP 668 / externally-managed-environment safeguard).
ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl wget \
       git \
       nano vim less \
       python3 python3-pip python3-venv \
       nmap dnsutils whois \
       netcat-openbsd tcpdump iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Useful Python tooling for exploit scripting / CTF-style work and simple web UI
RUN pip3 install --no-cache-dir \
      pwntools \
      requests \
      ipython \
      flask

WORKDIR /root

# Web UI for orchestrating common self-pentest actions
COPY webui /opt/ness-attack-webui

# Simple banner so you always know you're in the attack box
RUN printf '\n*** Ness Attack Platform (self-pentest only) ***\n' \
      'Target this container only at infrastructure you own / control. Do no harm.\n\n' \
      > /etc/motd

EXPOSE 18080

CMD ["bash", "-l"]
