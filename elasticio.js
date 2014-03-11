StockXmlImport = require('./main').StockXmlImport
Logger = require('./lib/logger')

exports.process = function(msg, cfg, next, snapshot) {
  console.log("Got elastic.io msg: %j", msg);
  logger = new Logger({ streams: [] });
  config = {
    client_id: cfg.sphereClientId,
    client_secret: cfg.sphereClientSecret,
    project_key: cfg.sphereProjectKey,
    timeout: 30000,
    logConfig: {
      logger: logger
    }
  };
  var im = new StockXmlImport({
    config: config
  });
  im.elasticio(msg, cfg, next, snapshot);
}
