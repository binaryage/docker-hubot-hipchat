# Description
#   An HTTP listener for FastSpring payment notifications
#
# Notes:
#   See FastSpring notifications overview for further details
#   https://support.fastspring.com/entries/236490-Notifications-Overview
#   https://support.fastspring.com/entries/22074351-Working-with-Variables-in-SpringBoard
#
# Author:
#   matteoagosti

bafs = require "./../lib/bafs"

module.exports = (robot) ->
  account = "totalfinder"
  env = process.env

  unless env.HUBOT_TF_FASTSPRING_PRIVATE_KEY
    robot.logger.error "Please set the HUBOT_TF_FASTSPRING_PRIVATE_KEY environment variable."
    return

  unless env.HUBOT_HIPCHAT_TOKEN
    robot.logger.error "Please set the HUBOT_HIPCHAT_TOKEN environment variable."
    return

  unless env.HUBOT_HIPCHAT_ROOM
    robot.logger.error "Please set the HUBOT_HIPCHAT_ROOM environment variable."
    return

  bafs(robot, account, env.HUBOT_TF_FASTSPRING_PRIVATE_KEY, env.HUBOT_HIPCHAT_TOKEN, env.HUBOT_HIPCHAT_ROOM)
