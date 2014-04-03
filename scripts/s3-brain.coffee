# Description:
#   Stores the brain in Amazon S3
#
# Dependencies:
#   "aws2js": "0.7.10"
#
# Configuration:
#   HUBOT_S3_BRAIN_ACCESS_KEY_ID      - AWS Access Key ID with S3 permissions
#   HUBOT_S3_BRAIN_SECRET_ACCESS_KEY  - AWS Secret Access Key for ID
#   HUBOT_S3_BRAIN_BUCKET             - Bucket to store brain in
#   HUBOT_S3_BRAIN_SAVE_INTERVAL      - [Optional] auto-save interval in seconds
#                                     Defaults to 30 minutes
#
# Commands:
#
# Notes:
#   Take care if using this brain storage with other brain storages.  Others may
#   set the auto-save interval to an undesireable value.  Since S3 requests have
#   an associated monetary value, this script uses a 30 minute auto-save timer
#   by default to reduce cost.
#
#   It's highly recommended to use an IAM account explicitly for this purpose
#   https://console.aws.amazon.com/iam/home?
#   A sample S3 policy for a bucket named Hubot-Bucket would be
#   {
#      "Statement": [
#        {
#          "Action": [
#            "s3:DeleteObject",
#            "s3:DeleteObjectVersion",
#            "s3:GetObject",
#            "s3:GetObjectAcl",
#            "s3:GetObjectVersion",
#            "s3:GetObjectVersionAcl",
#            "s3:PutObject",
#            "s3:PutObjectAcl",
#            "s3:PutObjectVersionAcl"
#          ],
#          "Effect": "Allow",
#          "Resource": [
#            "arn:aws:s3:::Hubot-Bucket/brain-dump.json"
#          ]
#        }
#      ]
#    }
#
# Author:
#   Iristyle

util  = require 'util'
aws   = require 'aws2js'

module.exports = (robot) ->

  loaded            = false
  key               = process.env.HUBOT_S3_BRAIN_ACCESS_KEY_ID
  secret            = process.env.HUBOT_S3_BRAIN_SECRET_ACCESS_KEY
  bucket            = process.env.HUBOT_S3_BRAIN_BUCKET
  save_interval     = process.env.HUBOT_S3_BRAIN_SAVE_INTERVAL || 30 * 60
  brain_dump_path   = "#{bucket}/brain-dump.json"

  if !key && !secret && !bucket
    throw new Error('S3 brain requires HUBOT_S3_BRAIN_ACCESS_KEY_ID, ' +
      'HUBOT_S3_BRAIN_SECRET_ACCESS_KEY and HUBOT_S3_BRAIN_BUCKET configured')

  save_interval = parseInt(save_interval)
  if isNaN(save_interval)
    throw new Error('HUBOT_S3_BRAIN_SAVE_INTERVAL must be an integer')

  s3 = aws.load('s3', key, secret)

  store_brain = (brain_data, callback) ->
    if !loaded
      robot.logger.debug 'Not saving to S3, because not loaded yet'
      return

    buffer = new Buffer(JSON.stringify(brain_data, undefined, 2))
    headers =
      'Content-Type': 'application/json'

    s3.putBuffer brain_dump_path, buffer, 'private', headers, (err, response) ->
      if err
        robot.logger.error util.inspect(err)
      else if response
        robot.logger.debug "Saved brain to S3 path #{brain_dump_path}"

      if callback then callback(err, response)

  robot.logger.debug "Loading brain from #{brain_dump_path}..."
  s3.get brain_dump_path, 'buffer', (err, response) ->
    if response && response.buffer
      memory = response.buffer.toString()
      robot.logger.info "Restoring brain memory from S3: (#{brain_dump_path})[#{memory.length} chars]"
      robot.brain.mergeData JSON.parse(memory)
    else
      robot.logger.info "No brain memory available at S3: #{brain_dump_path} => started with no memory"
      robot.brain.mergeData {}

  robot.brain.on 'loaded', () ->
    loaded = true
    robot.brain.resetSaveInterval(save_interval)

  robot.brain.on 'save', (data = {}) ->
    store_brain(data)
    
  robot.router.get "/hubot/s3brain/show", (req, res) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "BRAIN:\n" + JSON.stringify(robot.brain.data, undefined, 2)
    res.end response
    
  robot.router.get "/hubot/s3brain/forget", (req, res) ->
    robot.brain.data = {}
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "BRAIN:\n" + JSON.stringify(robot.brain.data, undefined, 2)
    res.end response
