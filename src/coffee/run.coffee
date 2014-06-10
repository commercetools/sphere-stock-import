fs = require 'q-io/fs'
Q = require 'q'
_ = require 'underscore'
path = require 'path'
tmp = require 'tmp'
{ExtendedLogger, ProjectCredentialsConfig, Qutils} = require 'sphere-node-utils'
package_json = require '../package.json'
StockImport = require './stockimport'
SftpHelper = require './sftp'

argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file] --logDir [dir] --logLevel [level]')
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('sphereHost', 'SPHERE.IO API host to connecto to')
  .describe('file', 'XML or CSV file containing inventory information to import')
  .describe('csvHeaders', 'a list of column names to use as mapping, comma separated')
  .describe('csvDelimiter', 'the delimiter type used in the csv')
  .describe('sftpCredentials', 'the path to a JSON file where to read the credentials from')
  .describe('sftpHost', 'the SFTP host (overwrite value in sftpCredentials JSON, if given)')
  .describe('sftpUsername', 'the SFTP username (overwrite value in sftpCredentials JSON, if given)')
  .describe('sftpPassword', 'the SFTP password (overwrite value in sftpCredentials JSON, if given)')
  .describe('sftpSource', 'path in the SFTP server from where to read the files')
  .describe('sftpTarget', 'path in the SFTP server to where to move the worked files')
  .describe('sftpFileRegex', 'a RegEx to filter files when downloading them')
  .describe('logLevel', 'log level for file logging')
  .describe('logDir', 'directory to store logs')
  .describe('logSilent', 'use console to print messages')
  .describe('timeout', 'Set timeout for requests')
  .default('csvHeaders', 'sku, quantity')
  .default('csvDelimiter', ',')
  .default('logLevel', 'info')
  .default('logDir', '.')
  .default('logSilent', false)
  .default('timeout', 60000)
  .demand(['projectKey'])
  .argv

logOptions =
  name: "#{package_json.name}-#{package_json.version}"
  streams: [
    { level: 'error', stream: process.stderr }
    { level: argv.logLevel, path: "#{argv.logDir}/#{package_json.name}.log" }
  ]
logOptions.silent = argv.logSilent if argv.logSilent
logger = new ExtendedLogger
  additionalFields:
    project_key: argv.projectKey
  logConfig: logOptions
if argv.logSilent
  logger.bunyanLogger.trace = -> # noop
  logger.bunyanLogger.debug = -> # noop

process.on 'SIGUSR2', -> logger.reopenFileStreams()
process.on 'exit', => process.exit(@exitCode)

importFn = (importer, fileName) ->
  throw new Error 'You must provide a file to be processed' unless fileName
  d = Q.defer()
  logger.debug "About to process file #{fileName}"
  mode = importer.getMode fileName
  fs.read fileName
  .then (content) ->
    logger.debug 'File read, running import'
    importer.run(content, mode)
    .then -> importer.summaryReport(fileName)
    .then (message) ->
      logger.withField({filename: fileName}).info message
      d.resolve(fileName)
    .fail (e) ->
      logger.error e, "Oops, something went wrong when processing file #{fileName}"
      d.reject 1
  .fail (e) ->
    logger.error e, "Cannot read file #{fileName}"
    d.reject 2
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

readJsonFromPath = (path) ->
  return Q({}) unless path
  fs.read(path).then (content) ->
    Q JSON.parse(content)

ProjectCredentialsConfig.create()
.then (credentials) =>
  options =
    config: credentials.enrichCredentials
      project_key: argv.projectKey
      client_id: argv.clientId
      client_secret: argv.clientSecret
    timeout: argv.timeout
    user_agent: "#{package_json.name} - #{package_json.version}"
    logConfig:
      logger: logger.bunyanLogger
    csvHeaders: argv.csvHeaders
    csvDelimiter: argv.csvDelimiter

  options.host = argv.sphereHost if argv.sphereHost

  stockimport = new StockImport logger, options

  file = argv.file

  if file
    importFn(stockimport, file)
    .then => @exitCode = 0 # process.exit 0
    .fail (code) => @exitCode = code # process.exit code
    .done()
  else
    tmp.setGracefulCleanup()

    readJsonFromPath(argv.sftpCredentials)
    .then (sftpCredentials) =>
      projectSftpCredentials = sftpCredentials[argv.projectKey] or {}
      {host, username, password} = _.defaults projectSftpCredentials,
        host: argv.sftpHost
        username: argv.sftpUsername
        password: argv.sftpPassword
      throw new Error 'Missing sftp host' unless host
      throw new Error 'Missing sftp username' unless username
      throw new Error 'Missing sftp password' unless password
      sftpHelper = new SftpHelper
        host: host
        username: username
        password: password
        sourceFolder: argv.sftpSource
        targetFolder: argv.sftpTarget
        fileRegex: argv.sftpFileRegex
        logger: logger
      createTmpDir()
      .then (tmpPath) =>
        logger.debug "Tmp folder created at #{tmpPath}"
        sftpHelper.download(tmpPath)
        .then (files) ->
          logger.debug files, "Processing #{files.length} files..."
          Qutils.processList files, (fileParts) ->
            throw new Error 'Files should be processed once at a time' if fileParts.length isnt 1
            file = fileParts[0]
            importFn(stockimport, "#{tmpPath}/#{file}")
            .then ->
              logger.debug "Finishing processing file #{file}"
              sftpHelper.finish(file)
          , {accumulate: false}
        .then =>
          logger.info 'Processing files to SFTP complete'
          @exitCode = 0
          # process.exit(0)
      .fail (error) =>
        logger.error error, 'Oops, something went wrong!'
        @exitCode = 1
        # process.exit(1)
      .done()
    .fail (err) =>
      logger.error err, "Problems on getting sftp credentials from config files."
      @exitCode = 1
      # process.exit(1)
    .done()
.fail (err) =>
  logger.error err, "Problems on getting client credentials from config files."
  @exitCode = 1
  # process.exit(1)
.done()