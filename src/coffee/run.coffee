fs = require 'q-io/fs'
path = require 'path'
package_json = require '../package.json'
StockImport = require './stockimport'
SftpHelper = require './sftp'

argv = require('optimist')
  .usage('Usage: $0 --projectKey [key] --clientId [id] --clientSecret [secret] --file [file]')
  .default('timeout', 60000)
  .describe('projectKey', 'your SPHERE.IO project-key')
  .describe('clientId', 'your OAuth client id for the SPHERE.IO API')
  .describe('clientSecret', 'your OAuth client secret for the SPHERE.IO API')
  .describe('file', 'XML or CSV file containing inventory information to import')
  .describe('sftpHost', 'the SFTP host')
  .describe('sftpUsername', 'the SFTP username')
  .describe('sftpPassword', 'the SFTP password')
  .describe('sftpSource', 'path in the SFTP server from where to read the files')
  .describe('sftpTarget', 'path in the SFTP server to where to move the worked files')
  .describe('timeout', 'Set timeout for requests')
  # .demand(['projectKey', 'clientId', 'clientSecret', 'file'])
  .argv

options =
  config:
    project_key: argv.projectKey
    client_id: argv.clientId
    client_secret: argv.clientSecret
  timeout: argv.timeout
  user_agent: "#{package_json.name} - #{package_json.version}"
  logConfig:
    streams: [
      { level: 'warn', stream: process.stderr }
      { level: 'warn', path: './sphere-stock-import.log' }
    ]

# stockimport = new StockImport options

fileName = argv.file
if fileName
  mode = stockimport.getMode fileName

  fs.read fileName
  .then (content) ->
    stockimport.run(content, mode)
    .then (result) ->
      console.info stockimport.sumResult(result)
      process.exit 0
    .fail (err) ->
      stockimport.client._logger.error err
      process.exit 1
  .fail (e) ->
    stockimport.client._logger.error "Problems on reading file '#{fileName}': #{err}"
    process.exit 2
else

  TMP_PATH = path.join __dirname, '../tmp'

  sftpHelper = new SftpHelper
    host: argv.sftpHost
    username: argv.sftpUsername
    password: argv.sftpPassword
    sourceFolder: argv.sftpSource
    targetFolder: argv.sftpTarget

  sftpHelper.download(TMP_PATH)
  .then (files) ->
    console.log files
    # TODO: process each file and move it on remote when finishing processing
    # sftpHelper.finish()
  .then ->
    console.log 'Cleaning tmp folder'
    sftpHelper.cleanup(TMP_PATH)
  .then ->
    console.log 'YAY!'
    process.exit()
  .fail (error) ->
    console.error error, 'Oops, something went wrong!'
    process.exit(1)
