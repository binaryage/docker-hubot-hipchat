http = require "http"
querystring = require "querystring"
crypto = require "crypto"
hipchat = require "node-hipchat"

module.exports = (robot, account, privateKey, hipchatToken, room) ->
  chat = new hipchat(hipchatToken);

  # just a test route
  robot.router.get "/hubot/fastspring/#{account}", (req, res) ->
    res.end "I'm here!"

  robot.router.post "/hubot/fastspring/#{account}", (req, res) ->
    query = req.body

    unless crypto.createHash("md5").update(query.security_data + privateKey, 'utf8').digest('hex') is query.security_hash
      res.writeHead 401, {'Content-Type': 'text/plain'}
      res.end "unauthorized"
      robot.logger.warning "Unauthorized request:\n#{query}"
      return

    moneyz = ""
    moneyz = " [#{query.totalValue} #{query.currency}]" if query.totalValue and parseInt(query.totalValue, 10)>0
    location = ""
    location = " from #{query.country}" if query.country
    verb = "bought"
    verb = "activated" if not moneyz
    message = "<a href='mailto:#{query.email}'>#{query.fullName}</a>#{location} just #{verb} <b>#{query.productName}</b>#{moneyz}"

    params = {
      room: room
      from: 'Hubot'
      message: message
      color: 'gray'
    }

    # jabber api is too loud
    # robot.messageRoom query.room, message

    chat.postMessage params, (data) ->
      if data and data.status == "sent"
        res.writeHead 200, {'Content-Type': 'text/plain'}
        res.end "OK"
      else
        res.writeHead 500, {'Content-Type': 'text/plain'}
        res.end "HipChat message failed to be delivered"
        robot.logger.warning "HipChat message failed to be delivered"
