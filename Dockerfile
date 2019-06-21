FROM python:3.7

RUN apt-get update && \
    apt-get install -y curl lsb-release gnupg apt-utils && \
    curl -sS --fail -L https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y curl vim apt-transport-https nano jq git groff nginx google-cloud-sdk && \
    rm -fr /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    pip install awscli cfn-flip cfn-lint yamllint yq && \
    curl -o /usr/local/bin/gomplate -sSL https://github.com/hairyhenderson/gomplate/releases/download/v2.7.0/gomplate_linux-amd64 && \
    chmod +x /usr/local/bin/gomplate &&  \
    ln -s /usr/local/bin/yq /usr/local/bin/aws /usr/local/bin/cfn-flip /usr/local/bin/cfn-lint /usr/bin


RUN echo "source /usr/lib/google-cloud-sdk/completion.bash.inc" >> .bashrc && \
    echo "complete -C $(which aws_completer) aws" >> .bashrc && \
    mkdir -p $HOME/.vim/pack/tpope/start && \
    git clone https://tpope.io/vim/sensible.git $HOME/.vim/pack/tpope/start/sensible && \
    vim -u NONE -c "helptags sensible/doc" -c q && \
    mkdir -p $HOME/.vim/colors && \
    curl -sS --fail -L -o $HOME/.vim/colors/basic-dark.vim https://raw.githubusercontent.com/zcodes/vim-colors-basic/master/colors/basic-dark.vim && \
    echo "include /usr/share/nano/*" > $HOME/.nanorc

COPY assets/  /var/www/html/assets/
COPY index.html.tmpl /opt/instruqt/
COPY docker-entrypoint.sh /opt/instruqt/

ENV PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

ENTRYPOINT [ "/opt/instruqt/docker-entrypoint.sh" ]
