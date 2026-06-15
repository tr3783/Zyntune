#!/bin/sh
set -e

# Install CocoaPods if not available
if ! command -v pod &> /dev/null; then
  gem install cocoapods
fi

cd $CI_PRIMARY_REPOSITORY_PATH/ios
pod install --repo-update
