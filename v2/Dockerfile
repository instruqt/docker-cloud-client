FROM python:3.14

# Update and install essential packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install --no-install-recommends -y \
        apt-transport-https \
        apt-utils \
        curl \
        git \
        gnupg \
        groff \
        jq \
        lsb-release \
        nano \
        nginx \
        unzip \
        vim \
        wget \
        zip && \
    rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK
RUN curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y kubectl google-cloud-sdk && \
    rm -rf /var/lib/apt/lists/*

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Install Microsoft GPG key and other tools
RUN curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    apt-get update && \
    apt-get install --no-install-recommends -y azure-cli && \
    rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws

# Install Python packages
RUN pip --no-cache-dir install \
    boto3 \
    cfn-flip \
    cfn-lint \
    yamllint \
    yq

# Install gomplate
RUN curl -sSL https://github.com/hairyhenderson/gomplate/releases/download/v2.7.0/gomplate_linux-amd64 -o /usr/local/bin/gomplate && \
    chmod +x /usr/local/bin/gomplate

# Create symbolic links for convenience
RUN ln -s /usr/local/bin/yq /usr/local/bin/aws /usr/local/bin/cfn-flip /usr/local/bin/cfn-lint /usr/bin

# Setup command completions and Vim configuration
RUN echo "source /usr/lib/google-cloud-sdk/completion.bash.inc" >> /etc/bash.bashrc && \
    echo "complete -C $(which aws_completer) aws" >> /etc/bash.bashrc && \
    echo "source /etc/bash_completion.d/azure-cli" >> /etc/bash.bashrc && \
    mkdir -p $HOME/.vim/pack/tpope/start && \
    git clone https://tpope.io/vim/sensible.git $HOME/.vim/pack/tpope/start/sensible && \
    vim -u NONE -c "helptags sensible/doc" -c q && \
    mkdir -p $HOME/.vim/colors && \
    curl -sS -o $HOME/.vim/colors/basic-dark.vim https://raw.githubusercontent.com/zcodes/vim-colors-basic/master/colors/basic-dark.vim && \
    echo "include /usr/share/nano/*" > $HOME/.nanorc

# Install code-server
RUN wget https://github.com/cdr/code-server/releases/download/2.1692-vsc1.39.2/code-server2.1692-vsc1.39.2-linux-x86_64.tar.gz -O /tmp/code-server.tar.gz && \
    tar -xzf /tmp/code-server.tar.gz --strip 1 -C /usr/bin && \
    rm /tmp/code-server.tar.gz

# Set environment variables and entrypoint
ENV PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
COPY docker-entrypoint.sh /opt/instruqt/
ENTRYPOINT [ "/opt/instruqt/docker-entrypoint.sh" ]

# Copy assets
COPY assets/ /var/www/html/assets/
COPY index.html.tmpl /opt/instruqt/
