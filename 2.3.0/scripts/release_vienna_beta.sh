#!/bin/bash

echo "Changing to project directory"
cd ..
echo "Changed to project directory"

echo "Building Vienna configuration DeploymentWithSymbols"
xcodebuild -project Vienna.xcodeproj -target Vienna -configuration DeploymentWithSymbols clean build
echo "Built Vienna configuration DeploymentWithSymbols"

echo "Building Vienna configuration Deployment"
xcodebuild -project Vienna.xcodeproj -target Vienna -configuration Deployment clean build DEPLOYMENT_POSTPROCESSING=YES VIENNA_IS_BETA=YES
echo "Built Vienna configuration Deployment"
