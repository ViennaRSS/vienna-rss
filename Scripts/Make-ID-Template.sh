#!/bin/sh

if [ ! -f Resources/CS-ID.xcconfig ]; then
    cat <<EOF > Resources/CS-ID.xcconfig
// Global settings for Code Signing

CODE_SIGN_IDENTITY = 
PRIVATE_KEY_PATH = 

CODE_SIGN_REQUIREMENTS_PATH = Resources/codesignrequirement.rqset
// CODE_SIGN_RESOURCE_RULES_PATH = $(SRCROOT)/signing/ResourceRules.plist

EOF
fi
