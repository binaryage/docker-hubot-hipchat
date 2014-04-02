# Description
#   An HTTP listener for FastSpring payment notifications
#
# Dependencies:
#   node-hipchat
#
# Configuration:
#   HUBOT_FASTSPRING_PRIVATE_KEY
#   HUBOT_HIPCHAT_TOKEN
#   HUBOT_HIPCHAT_ROOM
#
# Commands:
#   None
#
# URLS:
#   POST /hubot/fastspring
#     room=<room>
#     fullName=<customer's full name>
#     email=<customer's email>
#     productName=<product name, can also be an array of products>
#     totalPriceValue=<total price value>
#     totalPriceCurrency=<total price currency>
#     url=<invoice's url>
#
# Notes:
#   See FastSpring notifications overview for further details
#   https://support.fastspring.com/entries/236490-Notifications-Overview
#   https://support.fastspring.com/entries/22074351-Working-with-Variables-in-SpringBoard
#
# Author:
#   matteoagosti

http = require "http"
querystring = require "querystring"
crypto = require "crypto"
hipchat = require "node-hipchat"

module.exports = (robot) ->
  privateKey = process.env.HUBOT_FASTSPRING_PRIVATE_KEY
  hipchatToken = process.env.HUBOT_HIPCHAT_TOKEN
  
  TEST_ROOM_ID = 184938

  unless privateKey
    robot.logger.error "Please set the HUBOT_FASTSPRING_PRIVATE_KEY environment variable."
    return
    
  unless hipchatToken 
    robot.logger.error "Please set the HUBOT_HIPCHAT_TOKEN environment variable."
    return
    
  chat = new hipchat(hipchatToken);

  # just a test route
  robot.router.get "/hubot/fastspring/totalfinder", (req, res) ->
    res.end "I'm here!"

  robot.router.post "/hubot/fastspring/totalfinder", (req, res) ->
    query = req.body
        
    unless query.room
      res.writeHead 400, {'Content-Type': 'text/plain'}
      res.end "no room"
      return

    unless crypto.createHash("md5").update(query.security_data + privateKey, 'utf8').digest('hex') is query.security_hash
      res.writeHead 401, {'Content-Type': 'text/plain'}
      res.end "unauthorized"
      return
      
    moneyz = ""
    moneyz = " [#{query.totalValue}#{query.currency}]" if query.totalValue and parseInt(query.totalValue, 10)>0
    location = ""
    location = " from <i>#{query.country}</i>" if query.country
    verb = "bought"
    verb = "activated" if not moneyz
    message = "<a href='mailto:#{query.email}'>#{query.fullName}</a>#{location} just #{verb} <b>#{query.productName}</b>#{moneyz}"
    
    params = {
      room: process.env.HUBOT_HIPCHAT_ROOM || TEST_ROOM_ID
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
