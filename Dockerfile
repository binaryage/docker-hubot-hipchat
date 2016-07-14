FROM ubuntu:16.10

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

RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.31.2/install.sh | bash

# change it to your required node version
ENV NODE_VERSION 6.3.0

# needed by nvm install
ENV NVM_DIR /home/node/.nvm

RUN mkdir /home/node/hubot
WORKDIR /home/node/hubot

ENV PATH /home/node/hubot/node_modules/.bin:$PATH

# install the specified node version and set it as the default one, install the global npm packages
# note the npm shit must be all installed in one RUN command, layering images does not properly work with npm:
# https://github.com/npm/npm/issues/9863
RUN . ~/.nvm/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION \
  && npm install -g npm --user "node" \
  && npm install -g bower forever yo generator-hubot coffee-script hubot --user "node" \
  && yo hubot --name bahubot --defaults \
  && npm install --save hubot-hipchat \
  && npm install aws2js \
  && npm install node-hipchat \
  && npm install lodash

EXPOSE 8080

RUN rm hubot-scripts.json
ADD hubot-scripts.json /home/node/hubot/hubot-scripts.json
ADD scripts /home/node/hubot/scripts
ADD lib /home/node/hubot/lib
CMD . ~/.nvm/nvm.sh && hubot --adapter hipchat