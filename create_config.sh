#!/bin/bash

cat > "config.js" << EOF
/* SPHERE.IO credentials */
exports.config = {
  client_id: "${SPHERE_CLIENT_ID}",
  client_secret: "${SPHERE_CLIENT_SECRET}",
  project_key: "${SPHERE_PROJECT_KEY}",
  logentries_token: "${LOGENTRIES_TOKEN}",
  timeout: 60000
}
EOF