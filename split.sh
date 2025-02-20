#!/usr/bin/env bash

set -euo pipefail
# add debug info:
set -x

# go through all packages
path=packages/
commitMessage=$(git log -1 --pretty=format:"%s | %an <%ae> | %ad | https://github.com/Kanti/test-code-split-main-repo/commit/%H" --date=iso --no-show-signature)

mkdir -p tmp/

# set author for git
git config --global user.email "git@kanti.de"
git config --global user.name "Automated Splitter"

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

  currentMonoRepoTag=$(git tag --points-at HEAD)
  if [ ! -z "$currentMonoRepoTag" ]; then
    # only if the current package commit doesn't have a tag
    packageCommitTag=$(git -C tmp/${package}/ tag --points-at HEAD)
    if [ ! -z "$packageCommitTag" ]; then
      commit=$(git -C tmp/${package}/ rev-parse HEAD)
      echo -e "\033[33m[SKIPPING] ${package}:${packageCommitTag} Tag already exists for this commit ${commit}\033[0m"
      continue
    fi
    git -C tmp/${package}/ tag -s -e -f -a $currentMonoRepoTag -m "See more at https://github.com/Kanti/test-code-split-main-repo/releases/tag/${currentMonoRepoTag}" --no-edit
    git -C tmp/${package}/ push --tags
    gh release create $currentMonoRepoTag --notes-from-tag --verify-tag
  fi

done
