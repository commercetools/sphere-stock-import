#!/bin/bash

set -e

rm -rf lib
rm -rf node_modules

npm version patch
git checkout production
git merge master

npm install --production
grunt build
git add -f lib/
git add -f node_modules/
git commit -m "Add generated code and runtime dependencies for elastic.io environment."
git push origin production

git checkout master
npm version patch
git push origin master
npm install
