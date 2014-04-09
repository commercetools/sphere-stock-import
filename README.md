# sphere-stock-xml-import

[![Build Status](https://secure.travis-ci.org/hajoeichler/sphere-stock-xml-import.png?branch=master)](http://travis-ci.org/hajoeichler/sphere-stock-xml-import) [![Dependency Status](https://david-dm.org/hajoeichler/sphere-stock-xml-import.png?theme=shields.io)](https://david-dm.org/hajoeichler/sphere-stock-xml-import) [![devDependency Status](https://david-dm.org/hajoeichler/sphere-stock-xml-import/dev-status.png?theme=shields.io)](https://david-dm.org/hajoeichler/sphere-stock-xml-import#info=devDependencies)

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

* Just download the ready to use application as [ZIP](https://github.com/hajoeichler/sphere-stock-xml-import/archive/latest.zip)
* Extract the latest.zip with `unzip sphere-stock-xml-import-latest.zip`
* Change into the directory `cd sphere-stock-xml-import`

## General Usage

```
node lib/run

Usage: node ./lib/run.js --projectKey [key] --clientId [id] --clientSecret [secret] --file [file]

Options:
  --projectKey    your SPHERE.IO project-key                                  [required]
  --clientId      your OAuth client id for the SPHERE.IO API                  [required]
  --clientSecret  your OAuth client secret for the SPHERE.IO API              [required]
  --file          XML or CSV file containing inventory information to import  [required]
  --sftpHost      the SFTP host                                               [*optional]
  --sftpUsername  the SFTP username                                           [*optional]
  --sftpPassword  the SFTP password                                           [*optional]
  --sftpSource    path in the SFTP server from where to read the files        [*optional]
  --sftpTarget    path in the SFTP server to where to move the worked files   [*optional]
  --sftpFileRegex a RegEx to filter files when downloading them               [*optional]
  --logDir        log level for file logging                                  [default: info]
  --logLevel      directory to store logs                                     [default: .]
  --timeout       Set timeout for requests                                    [default: 300000]
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

> Please note that the header names are currenlty ignored.

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