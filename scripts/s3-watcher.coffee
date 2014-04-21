# Description
#   Hubot Script for watching changes in S3 and reporting to HipChat Room
#
# Dependencies:
#   node-hipchat
#
# Configuration:
#   HUBOT_HIPCHAT_TOKEN
#   HUBOT_HIPCHAT_ROOM
#   HUBOT_S3_WATCHER_ACCESS_KEY_ID
#   HUBOT_S3_WATCHER_SECRET_ACCESS_KEY
#   HUBOT_S3_WATCHER_HIPCHAT_SENDER
#   HUBOT_S3_WATCHER_HIPCHAT_COLOR
#   HUBOT_S3_WATCHER_CHECK_INTERVAL
#
# Commands:
#   None
#
# Notes:
#   None
#
# Author:
#   antonin@binaryage.com

http = require "http"
querystring = require "querystring"
hipchat = require "node-hipchat"
aws = require "aws2js"
_ = require "underscore"

module.exports = (robot) ->
  HIPCHAT_TOKEN = process.env.HUBOT_HIPCHAT_TOKEN
  HIPCHAT_ROOM = process.env.HUBOT_HIPCHAT_ROOM || 184938 # Test Room = 184938, BinaryAge Room = 100042
  S3_ACCESS_KEY_ID = process.env.HUBOT_S3_WATCHER_ACCESS_KEY_ID
  S3_SECRET_ACCESS_KEY = process.env.HUBOT_S3_WATCHER_SECRET_ACCESS_KEY
  HIPCHAT_SENDER = process.env.HUBOT_S3_WATCHER_HIPCHAT_SENDER || "S3 Watcher"
  HIPCHAT_COLOR = process.env.HUBOT_S3_WATCHER_HIPCHAT_COLOR || "purple"
  CHECK_INTERVAL = process.env.HUBOT_S3_WATCHER_CHECK_INTERVAL || 5 * 60 # once in 5 minutes
  CHECK_INTERVAL = parseInt(CHECK_INTERVAL, 10)

  if isNaN(CHECK_INTERVAL)
    throw new Error('HUBOT_S3_WATCHER_CHECK_INTERVAL must be an integer')

  unless HIPCHAT_TOKEN
    robot.logger.error "s3-watcher: Please set the HUBOT_HIPCHAT_TOKEN environment variable."
    return

  unless S3_ACCESS_KEY_ID
    robot.logger.error "s3-watcher: Please set the HUBOT_S3_WATCHER_ACCESS_KEY_ID environment variable."
    return

  unless S3_SECRET_ACCESS_KEY
    robot.logger.error "s3-watcher: Please set the HUBOT_S3_WATCHER_SECRET_ACCESS_KEY environment variable."
    return

  chat = new hipchat(HIPCHAT_TOKEN)

  #############################################################################

  # TODO: maybe this could be configurable in hubot's brain in the future
  isBucketIgnored = (bucketName) ->
    return true  if bucketName.match(/^hubot/) # hubot brain
    return true  if bucketName.match(/^s3hub/)
    return true  if bucketName.match(/^arq/) # arq backups
    return true  if bucketName.match(/^discuss-s3/)
    # note: discuss-backup-binaryage is enabled for now
    false

  isCDNBucket = (bucketName) ->
    bucketName=="downloads-s3.binaryage.com"

  run = (cb) ->
    counter = 0
    checked = 0
    fetchBucketNames (bucketNames) ->
      robot.logger.debug "s3-watcher: got #{bucketNames.length} buckets"
      cb("OK") unless bucketNames.length
      _.each bucketNames, (bucket) ->
        fetchBucketList bucket, (newList) ->
          robot.logger.debug "s3-watcher: got current #{newList.length} items in #{bucket}"
          checked += newList.length
          oldList = getCachedBucketList(bucket)
          robot.logger.debug "s3-watcher: got #{oldList.length} cached items in #{bucket}"
          report = buildReportForBucket(bucket, oldList, newList)
          if report.added.length or report.removed.length or report.modified.length
            robot.logger.debug "s3-watcher: RESULT: changed detected in #{bucket} (added=#{report.added.length} removed=#{report.removed.length} modified=#{report.modified.length})"
            reportToHipChat report
            storeBucketListInCache bucket, newList
            # prefetchCDN_ CDN_DOWNLOADS2_ID, CDN_LOGIN, CDN_PASSWORD, report  if bucket.match(/^downloads-1/)
          else
            robot.logger.debug "s3-watcher: RESULT: nothing changed in #{bucket}"
          counter+=1
          cb("OK - checked #{checked} items") if counter==bucketNames.length

  # see https://client.cdn77.com/help/prefetch#cdn
  # prefetchCDN_ = (cdnId, cdnLogin, cdnPassword, report) ->
  #   files = []
  #   join = (a, list) ->
  #     i = 0
  #
  #     while i < list.length
  #       path = "/" + list[i]
  #       a.push encodeURI(path)
  #       i++
  #     return
  #
  #   join files, report.added
  #   join files, report.modified
  #   options = method: "post"
  #   params =
  #     id: cdnId
  #     login: cdnLogin
  #     passwd: cdnPassword
  #     json: Utilities.jsonStringify(prefetch_paths: files.join("\n")).replace(/"/g, "'")
  #
  #   components = []
  #   for p of params
  #     components.push p + "=" + params[p]
  #   options.payload = components.join("&")
  #   query = "https://client.cdn77.com/api/prefetch"
  #   res = UrlFetchApp.fetch(query, options)
  #   robot.logger.log "s3-watcher: CDN PREFETCH " + res + ":\n" + query + "\n" + Utilities.jsonStringify(options)
  #   answer = Utilities.jsonParse(res.getContentText())
  #   return true  if answer and answer["status"] and answer["status"] is "ok"
  #   postMessageToHipChat "Failed to prefetch CDN [" + res.getResponseCode() + "]: " + res.getContentText()
  #   false

  postMessageToHipChat = (message) ->
    params =
      room: HIPCHAT_ROOM
      from: HIPCHAT_SENDER
      message: message
      color: HIPCHAT_COLOR

    robot.logger.debug "s3-watcher: about to post\n"+JSON.stringify(params, undefined, 2)
    chat.postMessage params, (data) ->
      if data and data.status == "sent"
        robot.logger.info "s3-watcher: a message to hipchat posted (#{message.length} chars)"
      else
        robot.logger.error "s3-watcher: unable to post to hipchat"

  reportToHipChat = (report) ->
    reportList = (intro, list, limit) ->
      body = []
      i = 0

      while i < list.length
        item = list[i]
        path = item
        url = "http://" + report.bucket + "/" + path
        markup = "<a href=\"" + url + "\">" + path + "</a>"
        markup = "  " + intro + markup
        body.push markup
        if (i is limit - 1) and (list.length - i) > 1
          body.push "  ... and " + intro + (list.length - i) + " other files"
          break
        i++
      return null  unless body.length
      body.join "<br/>"

    added = reportList("added ", report.added, 3)
    removed = reportList("removed ", report.removed, 3)
    modified = reportList("modified ", report.modified, 3)
    all = []
    all.push added  if added
    all.push modified  if modified
    if removed
      all.push removed
      if isCDNBucket(report.bucket)
        all.push "Warning: removed files might still be cached by CDN at http://downloads.binaryage.com. Use <a href='http://cdn77.com'>cdn77.com</a> to remove them."
    all = all.join("<br/>")
    lines = all.split("<br/>")
    bucketMarkup = "<a href=\"http://" + report.bucket + "\">" + report.bucket + "</a>"
    message = "Detected activity in bucket " + bucketMarkup + ":"
    if lines.length > 1
      message += "<br/>" + all
    else
      message += " " + all.trim()
    res = postMessageToHipChat(message)

  clearCache = ->
    delete robot.brain.data.s3watcher if robot.brain.data.s3watcher

  getCachedBucketList = (bucket) ->
    robot.brain.data.s3watcher?.buckets?[bucket] || []

  storeBucketListInCache = (bucket, list) ->
    robot.logger.debug "s3-watcher: stored #{list.length} items under #{bucket}"
    robot.brain.data.s3watcher = { buckets: {} } unless robot.brain.data.s3watcher
    robot.brain.data.s3watcher.buckets[bucket] = _.clone(list)

  fetchBucketList = (bucket, cb) ->
    tagTrimRe = new RegExp('\^"+|"+$', 'g')

    s3 = aws.load('s3', S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY)
    s3.setBucket(bucket)

    items = []
    robot.logger.debug "s3-watcher: fetchBucketList #{bucket}"
    fetch = (marker) ->
      query = ""
      query = "?marker=#{marker}" if marker
      robot.logger.debug "s3-watcher: fetchBucketList marker=#{marker}"
      s3.get '/', query, 'xml', (error, result) ->
        cb?(null, error) if error

        for obj in result["Contents"]
          key = obj["Key"]
          tag = obj["ETag"].replace(tagTrimRe, '')
          items.push
            path: key
            tag: tag

        if result["IsTruncated"] == "true"
          fetch(result["Marker"])
        else
          robot.logger.debug "s3-watcher: fetchBucketList done #{items.length}"
          cb(items)

    fetch()

  fetchBucketNames = (cb) ->
    robot.logger.debug "s3-watcher: fetchBucketNames"
    s3 = aws.load('s3', S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY)
    s3.get '/', 'xml', (error, result) ->
      cb?(null, error) if error

      names = []
      for obj in result["Buckets"]["Bucket"]
        name = obj.Name
        continue if isBucketIgnored(name)
        names.push name

      robot.logger.debug "s3-watcher: fetchBucketNames => #{names.length}"
      cb(names)

  buildReportForBucket = (bucket, oldList, newList) ->
    oldPaths = _.map oldList, (item) -> item.path
    newPaths = _.map newList, (item) -> item.path

    oldPathToTagMapping = {}
    for item in oldList
      oldPathToTagMapping[item.path] = item.tag

    newPathToTagMapping = {}
    for item in newList
      newPathToTagMapping[item.path] = item.tag

    removedPaths = _.difference(oldPaths, newPaths)
    addedPaths = _.difference(newPaths, oldPaths)
    stablePaths = _.difference(newPaths, addedPaths)

    modifiedPaths = []
    for path in stablePaths
      oldTag = oldPathToTagMapping[path]
      newTag = newPathToTagMapping[path]
      modifiedPaths.push path  unless oldTag is newTag

    report =
      bucket: bucket
      modified: modifiedPaths
      removed: removedPaths
      added: addedPaths

    report

  robot.router.get "/hubot/s3watcher/brain", (req, res) ->
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "STATE:\n" + JSON.stringify(robot.brain.data?.s3watcher, undefined, 2)
    res.end response

  robot.router.get "/hubot/s3watcher/reset", (req, res) ->
    clearCache()
    res.writeHead 200, {'Content-Type': 'text/plain'}
    response = "STATE:\n" + JSON.stringify(robot.brain.data?.s3watcher, undefined, 2)
    res.end response

  robot.router.get "/hubot/s3watcher/run", (req, res) ->
    run (result) ->
      res.writeHead 200, {'Content-Type': 'text/plain'}
      res.end result
      robot.logger.info "s3-watcher: TEST RUN => " + result

  worker = ->
    run (result) ->
      robot.logger.info "s3-watcher: SCHEDULED RUN => " + result
  setInterval(worker, CHECK_INTERVAL*1000)
  robot.logger.info "s3-watcher: scheduled to run every #{CHECK_INTERVAL} seconds"
