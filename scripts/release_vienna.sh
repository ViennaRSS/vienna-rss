#!/bin/bash

echo "Changing to project directory"
cd ..
echo "Changed to project directory"

echo "Building Vienna"
xcodebuild -project Vienna.xcodeproj -target Vienna -configuration Deployment clean build DEPLOYMENT_POSTPROCESSING=YES
echo "Built Vienna"
