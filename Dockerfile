# Utilitzem la imatge oficial d'Ubuntu 22.04 com a base
FROM ubuntu:22.04

# Establim fus horari
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Andorra

# Actualitzem el sistema i instalÂ·lem les dependÃ¨ies necessÃ es
RUN apt-get update && \
    apt-get install -y \
    software-properties-common \
    wget \
    apt-transport-https \
    gnupg2 \
    curl \
    tzdata \
    git \
    mailutils

# InstalÂ·lem Python 3.9
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.9 python3.9-venv python3.9-dev python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1 && \
    update-alternatives --set python3 /usr/bin/python3.9

# InstalÂ·lem PowerShell
RUN wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y powershell

# InstalÂ·lem el plugin de VMware per a PowerShell
RUN pwsh -Command "Install-Module -Name VMware.PowerCLI -Scope AllUsers -Force -AllowClobber"

# Executar la configuraciÃ³ PowerCLI
RUN pwsh -Command "Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP \$true -Confirm:\$false"

# InstalÂ·lem els paquets Python requerits
RUN pip install \
    bcrypt==4.0.1 \
    certifi==2024.2.2 \
    cffi==1.15.1 \
    charset-normalizer==2.0.6 \
    cryptography==39.0.1 \
    idna==3.2 \
    ipcalc==1.99.0 \
    lxml==5.1.0 \
    marshmallow==3.21.1 \
    netapp-lib==2021.6.25 \
    netapp-ontap==9.14.1.0 \
    networkscan==1.0.9 \
    numpy==1.26.2 \
    packaging==24.0 \
    pandas==2.1.4 \
    paramiko==3.0.0 \
    pip==24.0 \
    pycparser==2.21 \
    PyNaCl==1.5.0 \
    pynetbox==6.1.3 \
    python-dateutil==2.8.2 \
    python-dotenv==1.0.0 \
    pytz==2023.3.post1 \
    requests==2.26.0 \
    requests-toolbelt==1.0.0 \
    setuptools==57.4.0 \
    six==1.16.0 \
    tqdm==4.64.1 \
    tzdata==2023.3 \
    urllib3==1.26.7 \
    xmltodict==0.13.0

# Importar les claus de l'usuari que executa el build
RUN mkdir -p /root/.ssh
COPY id_rsa /root/.ssh/
COPY id_rsa.pub /root/.ssh/
RUN chmod 600 /root/.ssh/id_rsa
RUN chmod 644 /root/.ssh/id_rsa.pub

# Configurar Git per utilitzar les claus
RUN git config --global core.sshCommand "ssh -i /root/.ssh/id_rsa"

# Configurar Git
RUN git config --global user.email "reporter@global.ntt"
RUN git config --global user.name "Report"

# Crear els directoris /home/nttrmadm/
RUN mkdir -p /home/nttrmadm/

# Establir el directori de treball per defecte
WORKDIR /home/nttrmadm/
RUN ssh-keyscan -H gitlab.ntt.ms >> /root/.ssh/known_hosts
RUN git clone git@gitlab.ntt.ms:clients/cubeeu/internal/scripts/reports.git
WORKDIR /home/nttrmadm/reports/

# Eliminar lÃ­es duplicades i afegir la configuraciÃ³/etc/postfix/main.cf
RUN sed -i 's/^smtpd_relay_restrictions/#&/' /etc/postfix/main.cf && \
    sed -i 's/^myhostname/#&/' /etc/postfix/main.cf && \
    sed -i 's/^alias_maps/#&/' /etc/postfix/main.cf && \
    sed -i 's/^alias_database/#&/' /etc/postfix/main.cf && \
    sed -i 's/^mydestination/#&/' /etc/postfix/main.cf && \
    sed -i 's/^relayhost/#&/' /etc/postfix/main.cf && \
    sed -i 's/^mynetworks/#&/' /etc/postfix/main.cf && \
    sed -i 's/^mailbox_size_limit/#&/' /etc/postfix/main.cf && \
    sed -i 's/^recipient_delimiter/#&/' /etc/postfix/main.cf && \
    sed -i 's/^inet_interfaces/#&/' /etc/postfix/main.cf && \
    sed -i 's/^inet_protocols/#&/' /etc/postfix/main.cf && \
    echo 'mail_owner = postfix' >> /etc/postfix/main.cf && \
    echo 'myhostname = evl2401011' >> /etc/postfix/main.cf && \
    echo 'mydomain = sys.ntt.eu' >> /etc/postfix/main.cf && \
    echo 'resolve_null_domain = yes' >> /etc/postfix/main.cf && \
    echo 'myorigin = sys.ntt.eu' >> /etc/postfix/main.cf && \
    echo 'alias_maps = hash:/etc/aliases' >> /etc/postfix/main.cf && \
    echo 'alias_database = hash:/etc/aliases' >> /etc/postfix/main.cf && \
    echo 'mydestination = $myhostname, evl2403003, localhost.localdomain, localhost, evl2401011.sys.ntt.eu, sys.ntt.eu' >> /etc/postfix/main.cf && \
    echo 'relayhost = 13.95.145.251' >> /etc/postfix/main.cf && \
    echo 'mynetworks = 127.0.0.1' >> /etc/postfix/main.cf && \
    echo 'mailbox_size_limit = 0' >> /etc/postfix/main.cf && \
    echo 'inet_interfaces = all' >> /etc/postfix/main.cf && \
    echo 'inet_protocols = all' >> /etc/postfix/main.cf && \
    echo '#debug_peer_list = 127.0.0.1' >> /etc/postfix/main.cf && \
    echo '#debug_peer_level=2' >> /etc/postfix/main.cf && \
    echo '#maillog_file = /var/log/mail.log' >> /etc/postfix/main.cf && \
    service postfix restart

# Afegir l'script per substituir variables als fitxers .env
RUN cat <<EOF > /usr/local/bin/replace_env_vars.sh
#!/bin/bash

# Substituir les variables d'entorn als fitxers .env
sed -i "s/^CITRIX_PASSWORD=.*/CITRIX_PASSWORD=\\"\${CITRIX_PASSWORD}\\"/" /home/nttrmadm/reports/vip_report/.env
sed -i "s/^LB_PASS_PROD=.*/LB_PASS_PROD=\\"\${LB_PASS_PROD}\\"/" /home/nttrmadm/reports/LB-logs/.env
sed -i "s/^LB_PASS_PP=.*/LB_PASS_PP=\\"\${LB_PASS_PP}\\"/" /home/nttrmadm/reports/LB-logs/.env
EOF

RUN chmod +x /usr/local/bin/replace_env_vars.sh

# Configurar l'entrypoint 
CMD ["/bin/bash", "-c", "/usr/local/bin/replace_env_vars.sh && pwsh -Command 'while ($true) { Start-Sleep -Seconds 3600 }'"]