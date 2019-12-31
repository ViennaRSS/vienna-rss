#!/bin/sh

. "${OBJROOT}/autorevision.cache"

# Fail if not deployment
if [ ! "${CONFIGURATION}" = "Deployment" ]; then
	echo "error: This should only be run as Deployment" >&2
	exit 1
fi
# Fail if not clean
if [ ! "${VCS_WC_MODIFIED}" == "0" ]; then
	echo 'error: The Working directory is not clean; please commit or revert any changes.' 1>&2
	exit 1
fi
# Fail if not tagged
if [[ ! "${VCS_TICK}" == "0" ]]; then
	echo 'error: Not on a tag; please make a tag tag with `git tag -s` or `git tag -a`.' 1>&2
	exit 1
fi
# Fail if incorrectly tagged
if ! git describe --exact-match "${VCS_TAG}"; then
	echo 'error: The tag is not annotated; please redo the tag with `git tag -s` or `git tag -a`.' 1>&2
	exit 1
fi

# cf. https://furbo.org/2019/08/16/catalina-app-notarization-and-sparkle/
LOCATION="${BUILT_PRODUCTS_DIR}"/"${FRAMEWORKS_FOLDER_PATH}"
IDENTITY=${EXPANDED_CODE_SIGN_IDENTITY_NAME}

codesign --verbose --force --deep -o runtime --sign "$IDENTITY" "$LOCATION/Sparkle.framework/Versions/A/Resources/AutoUpdate.app"
codesign --verbose --force -o runtime --sign "$IDENTITY" "$LOCATION/Sparkle.framework/Versions/A"

exit 0
