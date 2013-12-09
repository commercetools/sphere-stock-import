#!/bin/bash

set -e

rm -rf lib

npm version minor
git checkout production
git merge master
grunt build
git add -f lib/

libs=($(jq .dependencies < package.json | grep ':' | cut -d':' -f1 | tr -d '"' | tr -d ' '))
for lib in ${libs[@]}; do
  git add -f "node_modules/${lib}"
done

git commit -m "Add generated code for production environment."
git push origin production

git checkout master
npm version patch
git push origin master
