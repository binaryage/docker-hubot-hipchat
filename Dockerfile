FROM ubuntu:12.10

RUN echo "deb http://archive.ubuntu.com/ubuntu quantal main universe" > /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get -y install wget git build-essential python libexpat1-dev libexpat1 libicu-dev

RUN mkdir /var/hubot
WORKDIR /var/hubot

RUN wget -O - http://nodejs.org/dist/v0.10.26/node-v0.10.26-linux-x64.tar.gz | tar -C /usr/local/ --strip-components=1 -zxv
RUN npm install -g coffee-script hubot
RUN hubot --create .
RUN npm install --save hubot-hipchat
RUN chmod 755 ./bin/hubot
RUN npm install aws2js node-hipchat underscore lodash # custom script dependencies
ENV PATH /var/hubot/bin:$PATH

EXPOSE 8080

RUN rm hubot-scripts.json
RUN rm scripts/roles.coffee # we are using simple HUBOT_AUTH_ADMIN env var
ADD hubot-scripts.json /var/hubot/hubot-scripts.json
ADD scripts /var/hubot/scripts
ADD lib /var/hubot/lib
CMD hubot --adapter hipchat