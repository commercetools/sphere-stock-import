StockXmlImport = require('./main').StockXmlImport

exports.process = function(msg, cfg, next, snapshot) {
  console.log("msg: %j", msg)
  console.log("cfg: %j", cfg)
  console.log("next: " + next)
  config = {
    client_id: cfg.sphereClientId,
    client_secret: cfg.sphereClientSecret,
    project_key: cfg.sphereProjectKey
  };
  var im = new StockXmlImport({
    config: config
  });
  im.elasticio(msg, cfg, next, snapshot);
}