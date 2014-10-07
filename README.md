# sphere-stock-import

[![Build Status](https://secure.travis-ci.org/sphereio/sphere-stock-import.png?branch=master)](http://travis-ci.org/sphereio/sphere-stock-import) [![Dependency Status](https://david-dm.org/sphereio/sphere-stock-import.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-stock-import) [![devDependency Status](https://david-dm.org/sphereio/sphere-stock-import/dev-status.png?theme=shields.io)](https://david-dm.org/sphereio/sphere-stock-import#info=devDependencies) [![Coverage Status](https://coveralls.io/repos/sphereio/sphere-stock-import/badge.png?branch=master)](https://coveralls.io/r/sphereio/sphere-stock-import?branch=master)

This repository contains an stock updater that can handle CSV and XML files.

# Setup

* install [NodeJS](http://support.sphere.io/knowledgebase/articles/307722-install-nodejs-and-get-a-component-running) (platform for running application)

### From scratch

* install [npm](http://gruntjs.com/getting-started) (NodeJS package manager, bundled with node since version 0.6.3!)
* install [grunt-cli](http://gruntjs.com/getting-started) (automation tool)
*  resolve dependencies using `npm`
```bash
$ npm install
```
* build javascript sources
```bash
$ grunt build
```

### From ZIP

* Just download the ready to use application as [ZIP](https://github.com/sphereio/sphere-stock-import/archive/latest.zip)
* Extract the latest.zip with `unzip sphere-stock-import-latest.zip`
* Change into the directory `cd sphere-stock-import`

## General Usage

```
node lib/run

Usage: node ./lib/run.js --projectKey [key] --clientId [id] --clientSecret [secret] --file [file]

Options:
  --projectKey              your SPHERE.IO project-key                                             [required]
  --clientId                your OAuth client id for the SPHERE.IO API
  --clientSecret            your OAuth client secret for the SPHERE.IO API
  --sphereHost              SPHERE.IO API host to connecto to
  --file                    XML or CSV file containing inventory information to import
  --csvHeaders              a list of column names to use as mapping, comma separated              [default: "sku, quantity"]
  --csvDelimiter            the delimiter type used in the csv                                     [default: ","]
  --sftpCredentials         the path to a JSON file where to read the credentials from
  --sftpHost                the SFTP host (overwrite value in sftpCredentials JSON, if given)
  --sftpUsername            the SFTP username (overwrite value in sftpCredentials JSON, if given)
  --sftpPassword            the SFTP password (overwrite value in sftpCredentials JSON, if given)
  --sftpSource              path in the SFTP server from where to read the files
  --sftpTarget              path in the SFTP server to where to move the worked files
  --sftpFileRegex           a RegEx to filter files when downloading them
  --sftpMaxFilesToProcess   how many files need to be processed, if more then one is found
  --sftpContinueOnProblems  ignore errors when processing a file and continue with the next one    [default: false]
  --sftpFileWithTimestamp   whether the processed file should be renamed by appending a timestamp  [default: false]
  --logLevel                log level for file logging                                             [default: "info"]
  --logDir                  directory to store logs                                                [default: "."]
  --logSilent               use console to print messages                                          [default: false]
  --timeout                 Set timeout for requests                                               [default: 60000]
```
> `*optional` means that they are required all together to use the SFTP functionality

#### CSV Format

Column 1 will be used as `SKU` identifier, whereas column 2 will be used as `quantity`.
An example:
```
sku,quantity
foo,9
bar,-1
SKU-123,42
```

> Please note that the header names are currently ignored.

#### XML Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<root>
  <row>
    <code>foo</code>
    <quantity>7</quantity>
  </row>
  <row>
    <code>bar</code>
    <quantity>1</quantity>
  </row>
</root>
```

## Contributing
In lieu of a formal styleguide, take care to maintain the existing coding style. Add unit tests for any new or changed functionality. Lint and test your code using [Grunt](http://gruntjs.com/).

## License
Copyright (c) 2013 Hajo Eichler and Nicola Molinari
Licensed under the MIT license.
