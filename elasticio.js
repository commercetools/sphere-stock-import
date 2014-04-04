package_json = require('./package.json')
StockImport = require('./lib/stockimport')

exports.process = function(msg, cfg, next, snapshot) {
  config = {
    client_id: cfg.sphereClientId,
    client_secret: cfg.sphereClientSecret,
    project_key: cfg.sphereProjectKey,
    timeout: 60000,
    user_agent: "#{package_json.name} - elasticio - #{package_json.version}",
    logConfig: {
      streams: []
    }
  };
  var im = new StockImport({
    config: config
  });
  im.elasticio(msg, cfg, next, snapshot);
}
