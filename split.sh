#!/usr/bin/env bash

set -euo pipefail
# add debug info:
set -x

# go through all packages
path=packages/
commitMessage=$(git log -1 --pretty=format:"%s | %an <%ae> | %ad | https://github.com/Kanti/test-code-split-main-repo/commit/%H" --date=iso --no-show-signature)

mkdir -p tmp/

for package in $(ls $path) ; do
  echo -e "\033[36m[INFO] ${package} started\033[0m"
  rm -rf tmp/${package}/
  git clone https://${GH_TOKEN}@github.com/Kanti/${package}.git tmp/${package}/
  rsync -avz --delete --exclude='.git' --exclude-from=.gitignore packages/${package}/ tmp/${package}/
  git -C tmp/${package}/ add .

  # if there is nothing to commit we can skip the commit and push
  if [ -z "$(git -C tmp/${package}/ status --porcelain)" ]; then
    # color yellow
    echo -e "\033[33m[SKIPPING] ${package} Nothing to commit\033[0m"
  else
    git -C tmp/${package}/ commit -m "${commitMessage}"
    git -C tmp/${package}/ push --follow-tags
  fi


  currentTag=$(git tag --points-at HEAD)
  if [ ! -z "$currentTag" ]; then
    GIT_TRACE=1 git -C tmp/${package}/ tag -s -e -f -a $currentTag -m "See more at https://github.com/Kanti/test-code-split-main-repo/releases/tag/${currentTag}" --no-edit
    git -C tmp/${package}/ push --tags
    gh release create $currentTag --notes-from-tag --verify-tag
  fi

done
