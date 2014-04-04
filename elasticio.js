var package_json = require('./package.json')
var StockImport = require('./lib/stockimport')
var bunyanLogentries = require('bunyan-logentries')

exports.process = function(msg, cfg, next, snapshot) {
  var config = {
    client_id: cfg.sphereClientId,
    client_secret: cfg.sphereClientSecret,
    project_key: cfg.sphereProjectKey,
    timeout: 60000,
    user_agent: "#{package_json.name} - elasticio - #{package_json.version}",
    logConfig: {
      streams: [
        { level: 'warn', stream: process.stderr }
      ]
    }
  };
  if (cfg.logentriesToken) {
    config.logConfig.streams.push({ level: 'info', stream: bunyanLogentries.createStream({token: cfg.logentriesToken}), type: 'raw' })
  }
  var im = new StockImport({
    config: config
  });
  im.elasticio(msg, cfg, next, snapshot);
}
