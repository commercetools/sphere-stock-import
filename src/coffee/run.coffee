fs = require 'q-io/fs'
Q = require 'q'
_ = require 'underscore'
path = require 'path'
tmp = require 'tmp'
{ProjectCredentialsConfig} = require 'sphere-node-utils'
package_json = require '../package.json'
Logger = require './logger'
StockImport = require './stockimport'
SftpHelper = require './sftp'

argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file] --logDir [dir] --logLevel [level]')
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('file', 'XML or CSV file containing inventory information to import')
  .describe('skuHeader', 'The name of the column containing the SKUs')
  .describe('quantityHeader', 'The name of the column containing the quantity information')
  .describe('sftpHost', 'the SFTP host')
  .describe('sftpUsername', 'the SFTP username')
  .describe('sftpPassword', 'the SFTP password')
  .describe('sftpSource', 'path in the SFTP server from where to read the files')
  .describe('sftpTarget', 'path in the SFTP server to where to move the worked files')
  .describe('sftpFileRegex', 'a RegEx to filter files when downloading them')
  .describe('logLevel', 'log level for file logging')
  .describe('logDir', 'directory to store logs')
  .describe('timeout', 'Set timeout for requests')
  .default('skuHeader', 'sku')
  .default('quantityHeader', 'quantity')
  .default('logLevel', 'info')
  .default('logDir', '.')
  .default('timeout', 60000)
  .demand(['projectKey'])
  .argv

logger = new Logger
  streams: [
    { level: 'error', stream: process.stderr }
    { level: argv.logLevel, path: "#{argv.logDir}/sphere-stock-xml-import_#{argv.projectKey}.log" }
  ]

process.on 'SIGUSR2', -> logger.reopenFileStreams()

importFn = (importer, fileName) ->
  throw new Error 'You must provide a file to be processed' unless fileName
  d = Q.defer()
  logger.info "About to process file #{fileName}"
  mode = importer.getMode fileName
  fs.read fileName
  .then (content) ->
    logger.info 'File read, running import'
    importer.run(content, mode)
    .then (result) ->
      logger.info importer.sumResult(result)
      d.resolve(fileName)
    .fail (e) ->
      logger.error e, "Oops, something went wrong when processing file #{fileName}"
      d.reject 1
  .fail (e) ->
    logger.error e, "Cannot read file #{fileName}"
    d.reject 2
  d.promise

processFn = (files, fn) ->
  throw new Error 'Please provide a function to process the files' unless _.isFunction fn
  d = Q.defer()
  _process = (tick) ->
    logger.info tick, 'Current tick'
    if tick >= files.length
      logger.info 'No more files, resolving...'
      d.resolve()
    else
      file = files[tick]
      fn(file)
      .then -> _process(tick + 1)
      .fail (error) -> d.reject error
      .done()
  _process(0)
  d.promise

###*
 * Simple temporary directory creation, it will be removed on process exit.
###
createTmpDir = ->
  d = Q.defer()
  # unsafeCleanup: recursively removes the created temporary directory, even when it's not empty
  tmp.dir {unsafeCleanup: true}, (err, path) ->
    if err
      d.reject err
    else
      d.resolve path
  d.promise

credentialsConfig = ProjectCredentialsConfig.create()
.then (credentials) ->
  options =
    config: credentials.enrichCredentials
      project_key: argv.projectKey
      client_id: argv.clientId
      client_secret: argv.clientSecret
    timeout: argv.timeout
    user_agent: "#{package_json.name} - #{package_json.version}"
    logConfig:
      logger: logger
    headerNames:
      skuHeader: argv.skuHeader
      quantityHeader: argv.quantityHeader

  stockimport = new StockImport options

  file = argv.file

  if file
    importFn(stockimport, file)
    .then -> process.exit 0
    .fail (code) -> process.exit code
    .done()
  else
    sftpHelper = new SftpHelper
      host: argv.sftpHost
      username: argv.sftpUsername
      password: argv.sftpPassword
      sourceFolder: argv.sftpSource
      targetFolder: argv.sftpTarget
      fileRegex: argv.sftpFileRegex
      logger: logger

    createTmpDir()
    .then (tmpPath) ->
      logger.info "Tmp folder created at #{tmpPath}"
      sftpHelper.download(tmpPath)
      .then (files) ->
        logger.info files, "Processing #{files.length} files..."
        processFn files, (file) ->
          importFn(stockimport, "#{tmpPath}/#{file}")
          .then ->
            logger.info "Finishing processing file #{file}"
            sftpHelper.finish(file)
      .then ->
        logger.info 'Processing files complete'
        process.exit(0)
    .fail (error) ->
      logger.error error, 'Oops, something went wrong!'
      process.exit(1)
    .done()
.fail (err) ->
  logger.error e, "Problems on getting client credentials from config files."
  process.exit(1)
.done()