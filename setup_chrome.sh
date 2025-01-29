#!/usr/bin/env bash
# exit on error
set -o errexit

STORAGE_DIR=/opt/render/project/.render

if [[ ! -d $STORAGE_DIR/chrome ]]; then
  echo "...Downloading Chrome"
  mkdir -p $STORAGE_DIR/chrome
  cd $STORAGE_DIR/chrome
  wget -P ./ https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  ar x ./google-chrome-stable_current_amd64.deb
  tar -xvf data.tar.xz -C $STORAGE_DIR/chrome  rm ./google-chrome-stable_current_amd64.deb data.tar.xz debian-binary
  rm ./google-chrome-stable_current_amd64.deb data.tar.xz debian-binary
  if [ -f control.tar.gz ]; then
    rm control.tar.gz
  fi
  cd $HOME/project/src # Make sure we return to where we were
else
  echo "...Using Chrome from cache"
fi

# be sure to add Chromes location to the PATH as part of your Start Command
# export PATH="${PATH}:/opt/render/project/.render/chrome/opt/google/chrome"
