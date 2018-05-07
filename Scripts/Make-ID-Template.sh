#!/bin/sh

if [ ! -f Scripts/Resources/CS-ID.xcconfig ]; then
    cat <<EOF > Scripts/Resources/CS-ID.xcconfig
// Global settings for Code Signing
// CODE_SIGN_IDENTITY should be the name of your certificate as it is stored in Keychain
// PRIVATE_KEY_PATH should be the location of the private DSA key used by Sparkle

CODE_SIGN_IDENTITY = 
PRIVATE_KEY_PATH = 

CODE_SIGN_REQUIREMENTS_PATH = \$(SRCROOT)/Scripts/Resources/codesignrequirement.rqset
// CODE_SIGN_RESOURCE_RULES_PATH = \$(SRCROOT)/Scripts/Resources/ResourceRules.plist

EOF
fi
