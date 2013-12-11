StockXmlImport = require('./main').StockXmlImport

exports.process = function(msg, cfg, cb, snapshot) {
  config = {
    client_id: cfg.clientId,
    client_secret: cfg.clientSecret,
    project_key: cfg.projectKey
  };
  var im = new StockXmlImport({
    config: config
  });
  im.elasticio(msg, cfg, cb, snapshot);
}