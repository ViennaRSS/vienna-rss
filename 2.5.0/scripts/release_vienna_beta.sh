#!/bin/bash

echo "Changing to project directory"
cd ..
echo "Changed to project directory"

echo "Building Vienna configuration Deployment"
xcodebuild -project Vienna.xcodeproj -target Release -configuration Deployment clean build VIENNA_CHANGELOG_SUFFIX="_beta"
echo "Built Vienna configuration Deployment"
