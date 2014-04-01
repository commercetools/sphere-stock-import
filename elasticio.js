StockXmlImport = require('./main').StockXmlImport

exports.process = function(msg, cfg, next, snapshot) {
  console.log("Got elastic.io msg: %j", msg);
  config = {
    client_id: cfg.sphereClientId,
    client_secret: cfg.sphereClientSecret,
    project_key: cfg.sphereProjectKey,
    timeout: 60000
  };
  var im = new StockXmlImport({
    config: config
  });
  im.elasticio(msg, cfg, next, snapshot);
}
