fs = require 'q-io/fs'
Q = require 'q'
_ = require 'underscore'
path = require 'path'
package_json = require '../package.json'
Logger = require './logger'
StockImport = require './stockimport'
SftpHelper = require './sftp'
{ProjectCredentialsConfig} = require 'sphere-node-utils'

argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file] --logDir [dir] --logLevel [level]')
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('file', 'XML or CSV file containing inventory information to import')
  .describe('sftpHost', 'the SFTP host')
  .describe('sftpUsername', 'the SFTP username')
  .describe('sftpPassword', 'the SFTP password')
  .describe('sftpSource', 'path in the SFTP server from where to read the files')
  .describe('sftpTarget', 'path in the SFTP server to where to move the worked files')
  .describe('logLevel', 'log level for file logging')
  .describe('logDir', 'directory to store logs')
  .describe('timeout', 'Set timeout for requests')
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

credentialsConfig = ProjectCredentialsConfig.create()
.fail (err) ->
  logger.error e, "Problems on getting client credentials from config files."
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

  stockimport = new StockImport options

  importFn = (fileName) ->
    throw new Error 'You must provide a file to be processed' unless fileName
    d = Q.defer()
    logger.info "About to process file #{fileName}"
    mode = stockimport.getMode fileName
    fs.read fileName
    .then (content) ->
      logger.info 'File read, running import'
      stockimport.run(content, mode)
      .then (result) ->
        logger.info stockimport.sumResult(result)
        d.resolve(fileName)
      .fail (e) ->
        logger.error e, "Oops, something went wrong when processing file #{fileName}"
        d.reject 1
    .fail (e) ->
      logger.error e, "Cannot read file #{fileName}"
      d.reject 2
    d.promise

  file = argv.file

  if file
    importFn(file)
    .then -> process.exit 0
    .fail (code) -> process.exit code
    .done()
  else

    TMP_PATH = path.join __dirname, '../tmp'

    sftpHelper = new SftpHelper
      host: argv.sftpHost
      username: argv.sftpUsername
      password: argv.sftpPassword
      sourceFolder: argv.sftpSource
      targetFolder: argv.sftpTarget
      logger: logger

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
          .then ->
            logger.info "Finishing processing file #{file}"
            sftpHelper.finish(file)
          .then ->
            _process(tick + 1)
          .fail (error) -> d.reject error
          .done()
      _process(0)
      d.promise

    sftpHelper.download(TMP_PATH)
    .then (files) ->
      logger.info files, "Processing #{files.length} files..."
      processFn files, (file) -> importFn("#{TMP_PATH}/#{file}")
    .then ->
      logger.info 'Cleaning tmp folder'
      sftpHelper.cleanup(TMP_PATH)
    .then ->
      process.exit(0)
    .fail (error) ->
      logger.error error, 'Oops, something went wrong!'
      process.exit(1)
