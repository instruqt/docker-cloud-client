FROM python:3.8

RUN apt-get update && \
    apt-get install --no-install-recommends -y curl lsb-release gnupg apt-utils && \
    curl -sS --fail -L https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list && \
    curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null && \
    apt-get update && \
    apt-get install --no-install-recommends -y curl vim apt-transport-https nano jq git groff nginx zip httpie google-cloud-sdk kubectl azure-cli && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip --no-cache-dir install awscli cfn-flip cfn-lint yamllint yq boto3 && \
    curl -o /usr/local/bin/gomplate -sSL https://github.com/hairyhenderson/gomplate/releases/download/v2.7.0/gomplate_linux-amd64 && \
    chmod +x /usr/local/bin/gomplate &&  \
    ln -s /usr/local/bin/yq /usr/local/bin/aws /usr/local/bin/cfn-flip /usr/local/bin/cfn-lint /usr/bin
    pip uninstall awscli -y && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && hash  -r && \
    rm -rf /root/awscliv2.zip /root/aws

RUN echo "source /usr/lib/google-cloud-sdk/completion.bash.inc" >> /etc/bash.bashrc && \
    echo "complete -C $(which aws_completer) aws" >> /etc/bash.bashrc && \
    echo "source /etc/bash_completion.d/azure-cli" >> /etc/bash.bashrc && \
    mkdir -p $HOME/.vim/pack/tpope/start && \
    git clone https://tpope.io/vim/sensible.git $HOME/.vim/pack/tpope/start/sensible && \
    vim -u NONE -c "helptags sensible/doc" -c q && \
    mkdir -p $HOME/.vim/colors && \
    curl -sS --fail -L -o $HOME/.vim/colors/basic-dark.vim https://raw.githubusercontent.com/zcodes/vim-colors-basic/master/colors/basic-dark.vim && \
    echo "include /usr/share/nano/*" > $HOME/.nanorc

RUN wget https://github.com/cdr/code-server/releases/download/2.1692-vsc1.39.2/code-server2.1692-vsc1.39.2-linux-x86_64.tar.gz -O /tmp/code-server.tar.gz --no-check-certificate && \
    tar -xzf /tmp/code-server.tar.gz --strip 1 -C /usr/bin && \
    rm /tmp/code-server.tar.gz

ENV PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENTRYPOINT [ "/opt/instruqt/docker-entrypoint.sh" ]
COPY docker-entrypoint.sh /opt/instruqt/

COPY assets/  /var/www/html/assets/
COPY index.html.tmpl /opt/instruqt/
