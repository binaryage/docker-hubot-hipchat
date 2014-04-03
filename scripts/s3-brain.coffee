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
  key               = process.env.HUBOT_S3_BRAIN_ACCESS_KEY_ID
  secret            = process.env.HUBOT_S3_BRAIN_SECRET_ACCESS_KEY
  bucket            = process.env.HUBOT_S3_BRAIN_BUCKET
  saveInterval      = process.env.HUBOT_S3_BRAIN_SAVE_INTERVAL || 30 * 60
  brainPath         = process.env.HUBOT_S3_BRAIN_PATH || "#{bucket}/brain-dump.json"
  loaded            = false
  lastSavedState    = null

  if !key && !secret && !bucket
    throw new Error('S3 brain requires HUBOT_S3_BRAIN_ACCESS_KEY_ID, ' +
      'HUBOT_S3_BRAIN_SECRET_ACCESS_KEY and HUBOT_S3_BRAIN_BUCKET configured')

  saveInterval = parseInt(saveInterval)
  if isNaN(saveInterval)
    throw new Error('HUBOT_S3_BRAIN_SAVE_INTERVAL must be an integer')

  s3 = aws.load('s3', key, secret)
  
  # data structure -> JSON string
  serialize = (data) ->
    res = ""
    try
      res = JSON.stringify(data, undefined, 2)
    catch e
      robot.logger.error "s3-brain: Unable to serialize brain state: #{e.message}"
    res

  # JSON string -> data structure
  unserialize = (buffer) ->
    res = {}
    try
      res = JSON.parse(buffer)
    catch e
      robot.logger.error "s3-brain: Unable to unserialize brain memory: #{e.message}"
    res

  saveBrain = (brainData, callback) ->
    if !loaded
      robot.logger.debug "s3-brain: Not saving to S3, because not loaded yet"
      return
      
    json = serialize(brainData)
    if _.isEqual(json, lastSavedState) # optimization, save only when anything changed
      robot.logger.debug "s3-brain: Not saving to S3, no brain changes"
      return

    buffer = new Buffer(json)
    headers =
      'Content-Type': 'application/json'

    s3.putBuffer brainPath, buffer, 'private', headers, (err, response) ->
      if err
        robot.logger.error util.inspect(err)
      else if response
        robot.logger.info "s3-brain: Saved brain to S3: #{brainPath}[#{json.length} chars]"

      if callback then callback(err, response)

  loadBrain = ->
    robot.logger.debug "Loading brain from #{brainPath}..."
    s3.get brainPath, 'buffer', (err, response) ->
      if response && response.buffer
        json = response.buffer.toString()
        robot.logger.info "s3-brain: Restoring brain memory from S3: #{brainPath}[#{json.length} chars]"
        robot.brain.mergeData unserialize(json)
      else
        robot.logger.info "s3-brain: No brain memory available in S3: #{brainPath} => started with no memory"
        robot.brain.mergeData {}
        
  robot.brain.on 'loaded', () ->
    loaded = true
    robot.brain.resetSaveInterval(saveInterval)

  robot.brain.on 'save', (data = {}) ->
    saveBrain(data)
    
  robot.router.get "/hubot/s3brain/show", (req, res) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "BRAIN:\n" + serialize(robot.brain.data)
    res.end response
    
  robot.router.get "/hubot/s3brain/forget", (req, res) ->
    robot.brain.data = {}
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "BRAIN:\n" + serialize(robot.brain.data)
    res.end response

  # load brain on startup
  loadBrain()