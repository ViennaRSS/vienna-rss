#!/bin/bash

echo "Changing to project directory"
cd ..
echo "Changed to project directory"

echo "Building Vienna configuration Deployment"
xcodebuild -project Vienna.xcodeproj -target Vienna -configuration Deployment clean build DEPLOYMENT_POSTPROCESSING=YES
echo "Built Vienna configuration Deployment"
