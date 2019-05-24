FROM nginx

RUN apt-get update
RUN apt-get install -y curl vim lsb-release apt-transport-https gnupg nano jq git awscli
RUN echo "deb http://packages.cloud.google.com/apt cloud-sdk-$(lsb_release -c -s) main" > /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-key adv --fetch-keys https://packages.cloud.google.com/apt/doc/apt-key.gpg
RUN apt-get update
RUN apt-get install -y google-cloud-sdk

RUN echo "source /usr/lib/google-cloud-sdk/completion.bash.inc" >> .bashrc
RUN echo "complete -C $(which aws_completer) aws" >> .bashrc

RUN curl -o /usr/local/bin/gomplate -sSL https://github.com/hairyhenderson/gomplate/releases/download/v2.7.0/gomplate_linux-amd64 && \
    chmod +x /usr/local/bin/gomplate
RUN curl -L -sS -o /usr/local/bin/yaml2json https://github.com/bronze1man/yaml2json/releases/download/v1.3/yaml2json_linux_amd64 && \
    chmod +x /usr/local/bin/yaml2json

RUN mkdir -p $HOME/.vim/pack/tpope/start && \
    git clone https://tpope.io/vim/sensible.git $HOME/.vim/pack/tpope/start/sensible && \
    vim -u NONE -c "helptags sensible/doc" -c q && \
    mkdir -p $HOME/.vim/colors && \
    curl -L -o $HOME/.vim/colors/basic-dark.vim https://raw.githubusercontent.com/zcodes/vim-colors-basic/master/colors/basic-dark.vim
RUN echo "include /usr/share/nano/*" > $HOME/.nanorc

COPY assets/ /usr/share/nginx/html/assets/
COPY index.html.tmpl /opt/instruqt/
COPY docker-entrypoint.sh /opt/instruqt/

ENTRYPOINT [ "/opt/instruqt/docker-entrypoint.sh" ]
