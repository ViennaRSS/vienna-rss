#!/bin/bash

echo "Changing to project directory"
cd ..
echo "Changed to project directory"

echo "Building Vienna configuration Deployment"
xcodebuild -project Vienna.xcodeproj -target Vienna -configuration Deployment clean build DEPLOYMENT_POSTPROCESSING=YES VIENNA_CHANGELOG_SUFFIX="_beta"
echo "Built Vienna configuration Deployment"
