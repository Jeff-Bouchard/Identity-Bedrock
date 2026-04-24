# Ness Attack Platform container (self-pentest box)
# Base: Debian stable with common PWK-style tools.
# Goal: lightweight but useful attacker environment you can run
# against your own Ness stack.
#
# Scope: authorized self-pentest on infrastructure you own/control only.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
# PEP 668 / externally-managed-environment safeguard bypass for container
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# ── System packages (all verified in debian:bookworm repos) ───────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl wget git \
       nano vim less file \
       python3 python3-pip python3-venv \
       nmap dnsutils whois traceroute \
       netcat-openbsd tcpdump iproute2 \
       socat jq openssl \
       sqlmap hydra \
    && rm -rf /var/lib/apt/lists/*

# ── Tools not in bookworm repos — install from source / releases ───
# nikto — web server scanner
RUN git clone --depth 1 https://github.com/sullo/nikto.git /opt/nikto \
    && ln -s /opt/nikto/program/nikto.pl /usr/local/bin/nikto \
    && chmod +x /opt/nikto/program/nikto.pl

# testssl.sh — SSL/TLS checker
RUN git clone --depth 1 https://github.com/drwetter/testssl.sh.git /opt/testssl \
    && ln -s /opt/testssl/testssl.sh /usr/local/bin/testssl \
    && chmod +x /opt/testssl/testssl.sh

# ── OpenSSL 3.6.2 from source (post-quantum: ML-KEM / ML-DSA) ─────────
# Debian bookworm ships 3.0.x — too old for PQ. Build 3.6.2 into /opt/openssl
# and expose via LD_LIBRARY_PATH so sslscan / testssl / sslyze pick it up.
RUN OSSL_VER="3.6.2" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       make gcc perl libc6-dev zlib1g-dev \
    && curl -sL "https://github.com/openssl/openssl/releases/download/openssl-${OSSL_VER}/openssl-${OSSL_VER}.tar.gz" \
       | tar xz -C /tmp \
    && cd /tmp/openssl-${OSSL_VER} \
    && ./config --prefix=/opt/openssl --openssldir=/opt/openssl/ssl \
       enable-ml-kem enable-ml-dsa \
    && make -j$(nproc) \
    && make install_sw \
    && rm -rf /tmp/openssl-${OSSL_VER} \
    && apt-get purge -y make gcc perl libc6-dev zlib1g-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=/opt/openssl/lib64:/opt/openssl/lib:${LD_LIBRARY_PATH}
ENV PATH=/opt/openssl/bin:${PATH}

# sslscan — TLS scanner (built against our PQ-capable OpenSSL 3.6)
# Symlink /usr/local/ssl → /opt/openssl so sslscan's Makefile hard-coded
# -L/usr/local/ssl/lib and -I/usr/local/ssl/include resolve correctly.
RUN ln -sf /opt/openssl /usr/local/ssl \
    && apt-get update \
    && apt-get install -y --no-install-recommends make gcc git libc6-dev \
    && git clone --depth 1 https://github.com/rbsec/sslscan.git /tmp/sslscan-src \
    && make -C /tmp/sslscan-src \
    && cp /tmp/sslscan-src/sslscan /usr/local/bin/ \
    && rm -rf /tmp/sslscan-src \
    && apt-get purge -y make gcc git libc6-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# ffuf — fast web fuzzer (single Go binary, replaces dirb)
RUN FFUF_VER="2.1.0" \
    && curl -sL "https://github.com/ffuf/ffuf/releases/download/v${FFUF_VER}/ffuf_${FFUF_VER}_linux_amd64.tar.gz" \
       | tar xz -C /usr/local/bin ffuf \
    && chmod +x /usr/local/bin/ffuf

# gobuster — directory/file brute-forcer (Go binary, tar.gz since v3.7+)
RUN GOBUSTER_VER="3.8.2" \
    && curl -sL "https://github.com/OJ/gobuster/releases/download/v${GOBUSTER_VER}/gobuster_Linux_x86_64.tar.gz" \
       | tar xz -C /tmp \
    && cp /tmp/gobuster /usr/local/bin/gobuster \
    && chmod +x /usr/local/bin/gobuster \
    && rm -f /tmp/gobuster

# wordlists for ffuf / gobuster / hydra / sqlmap
RUN mkdir -p /usr/share/wordlists \
    && curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" \
       -o /usr/share/wordlists/common.txt \
    && curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/darkweb2017-top100.txt" \
       -o /usr/share/wordlists/top100-passwords.txt

# ── Python tooling: exploit scripting, protocol libs, web UI ───────
RUN pip3 install --no-cache-dir \
      pwntools \
      requests httpx \
      ipython \
      flask \
      scapy \
      paramiko cryptography \
      impacket \
      dnspython \
      sslyze \
      beautifulsoup4 \
      python-nmap

WORKDIR /root

# Web UI for orchestrating common self-pentest actions
COPY webui /opt/ness-attack-webui

# Banner so you always know you're in the attack box
RUN printf '\n*** Ness Attack Platform (self-pentest only) ***\n' \
      'Target this container only at infrastructure you own / control. Do no harm.\n\n' \
      > /etc/motd

# Flask default inside container; host-side port is chosen by run-console.sh
EXPOSE 18080

CMD ["bash", "-l"]
