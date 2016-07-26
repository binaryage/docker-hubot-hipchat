FROM ubuntu:15.04

# following setup taken from
#   https://github.com/iliyan-trifonov/docker-node-nvm/blob/96a94d74b8922dded5fce45a08ec367aeb5750c8/Dockerfile

RUN apt-get update
RUN apt-get install -y curl git python build-essential

# add user node and use it to install node/npm and run the app
RUN useradd --home /home/node -m -U -s /bin/bash node

# allow some limited sudo commands for user `node`
RUN echo 'Defaults !requiretty' >> /etc/sudoers; \
    echo 'node ALL= NOPASSWD: /usr/sbin/dpkg-reconfigure -f noninteractive tzdata, /usr/bin/tee /etc/timezone, /bin/chown -R node\:node /myapp' >> /etc/sudoers;

# run all of the following commands as user node from now on
USER node

RUN curl https://raw.githubusercontent.com/creationix/nvm/v0.29.0/install.sh | bash

# change it to your required node version
ENV NODE_VERSION 4.2.1

# needed by nvm install
ENV NVM_DIR /home/node/.nvm

RUN mkdir /home/node/hubot
WORKDIR /home/node/hubot

# install the specified node version and set it as the default one, install the global npm packages
RUN . ~/.nvm/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION && npm install -g bower forever --user "node"
RUN . ~/.nvm/nvm.sh && npm install yo generator-hubot coffee-script hubot --user "node"

ENV PATH /home/node/hubot/node_modules/.bin:$PATH

# finally create hubot

RUN . ~/.nvm/nvm.sh && yo hubot --defaults
RUN . ~/.nvm/nvm.sh && npm install --save hubot-hipchat
RUN . ~/.nvm/nvm.sh && npm install aws2js node-hipchat underscore lodash # custom script dependencies

EXPOSE 8080

RUN rm hubot-scripts.json
ADD hubot-scripts.json /home/node/hubot/hubot-scripts.json
ADD scripts /home/node/hubot/scripts
ADD lib /home/node/hubot/lib
CMD . ~/.nvm/nvm.sh && hubot --adapter hipchat