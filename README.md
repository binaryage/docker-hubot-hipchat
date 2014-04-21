# Dockerized Hubot in BinaryAge

## Deploying

* `docker build -t my-hubot .`
* To run it with right environment see [binaryage/info wiki](https://github.com/binaryage/info/wiki/Hubot)

## Custom scripts

Our Hubot loads default set of scripts except `roles.coffee`.
Additioanlly it loads our [custom scripts](scripts).

## Resources

The [hipchat-hubot](https://github.com/hipchat/hubot-hipchat) is a good place
to start as it describes how to setup both Hipchat and Hubot.

Hubot docs can be found in the [hubot repo](https://github.com/github/hubot).
