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
    {host, username, password, @sourceFolder, @targetFolder} = options
    # TODO: validate options
    @sftpClient = new Sftp
      host: host
      username: username
      password: password

  download: (tmpFolder) ->
    d = Q.defer()
    fs.exists(tmpFolder)
    .then (exists) ->
      if exists
        Q()
      else
        fs.makeDirectory tmpFolder
    .then => @sftpClient.openSftp()
    .then (sftp) =>
      @_sftp = sftp
      @sftpClient.listFiles(sftp, @sourceFolder)
    .then (files) =>
      Q.all _.filter(files, (f) ->
        switch f.filename
          when '.', '..' then false
          else true
      ).map (f) =>
        @sftpClient.getFile(@_sftp, "#{@sourceFolder}/#{f.filename}", "#{tmpFolder}/#{f.filename}")
    .then -> fs.list(tmpFolder)
    .then (files) -> d.resolve(files)
    .fail (error) -> d.reject error
    .fin =>
      console.log 'Closing connection'
      @sftpClient.close(@_sftp)
    d.promise

  process: ->

  finish: (fileName) ->
    d = Q.defer()
    @sftpClient.openSftp()
    .then (sftp) =>
      @_sftp = sftp
      @sftpClient.moveFile(sftp, "#{@sourceFolder}/#{fileName}", "#{@targetFolder}/#{fileName}")
    .then -> d.resolve()
    .fail (error) -> d.reject error
    .fin => @sftpClient.close(@_sftp)
    d.promise

  cleanup: (tmpFolder) -> fs.removeTree(tmpFolder)
