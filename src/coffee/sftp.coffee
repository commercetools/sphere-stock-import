fs = require 'q-io/fs'
_ = require 'underscore'
Q = require 'q'
{Sftp} = require 'sphere-node-utils'

module.exports = class

  ###*
   * @constructor
   * Initialize {Sftp} client
   * @param {Object} [options] Configuration for {Sftp}
  ###
  constructor: (options = {}) ->
    {host, username, password, @sourceFolder, @targetFolder, @logger} = options
    # TODO: validate options
    @sftpClient = new Sftp
      host: host
      username: username
      password: password

  download: (tmpFolder) ->
    d = Q.defer()
    fs.exists(tmpFolder)
    .then (exists) =>
      if exists
        Q()
      else
        @logger.info 'Creating new tmp folder'
        fs.makeDirectory tmpFolder
    .then => @sftpClient.openSftp()
    .then (sftp) =>
      @logger.info 'New connection opened'
      @_sftp = sftp
      @sftpClient.listFiles(sftp, @sourceFolder)
    .then (files) =>
      @logger.info 'Downloading files'
      @logger.debug files
      Q.all _.filter(files, (f) ->
        switch f.filename
          when '.', '..' then false
          else true
      ).map (f) =>
        @sftpClient.getFile(@_sftp, "#{@sourceFolder}/#{f.filename}", "#{tmpFolder}/#{f.filename}")
    .then -> fs.list(tmpFolder)
    .then (files) ->
      d.resolve _.filter files, (fileName) ->
        switch
          when fileName.match /\.csv$/i then true
          when fileName.match /\.xml$/i then true
          else false
    .fail (error) -> d.reject error
    .fin =>
      @logger.info 'Closing connection'
      @sftpClient.close(@_sftp)
    d.promise

  finish: (fileName) ->
    d = Q.defer()
    @sftpClient.openSftp()
    .then (sftp) =>
      @logger.info 'New connection opened'
      @_sftp = sftp
      @logger.info "Renaming file #{fileName} on the remote server"
      @sftpClient.moveFile(sftp, "#{@sourceFolder}/#{fileName}", "#{@targetFolder}/#{fileName}")
    .then -> d.resolve()
    .fail (error) -> d.reject error
    .fin => @sftpClient.close(@_sftp)
    d.promise

  cleanup: (tmpFolder) -> fs.removeTree(tmpFolder)