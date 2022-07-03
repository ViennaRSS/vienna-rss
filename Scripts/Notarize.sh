#!/bin/bash

# Some ideas derived from https://twocanoes.com/adding-notarization-to-xcode-builds/

. "${SOURCE_ROOT}/Build/Post-archive-exports.txt"

# Fail if not deployment
if [ ! "${CONFIGURATION}" = "Deployment" ]; then
	echo "error: This should only be run as Deployment" >&2
	exit 1
fi

local_apps_dir="${ARCHIVE_PATH}/Products/Applications"
app_path="${local_apps_dir}/Vienna.app"

# cf. https://furbo.org/2019/08/16/catalina-app-notarization-and-sparkle/
LOCATION="${app_path}/Contents/Frameworks"

codesign --verbose --force --deep -o runtime --sign "${CODE_SIGN_IDENTITY}" "$LOCATION/Sparkle.framework/Versions/A/Resources/AutoUpdate.app"
codesign --verbose --force -o runtime --sign "${CODE_SIGN_IDENTITY}" "$LOCATION/Sparkle.framework/Versions/A"

codesign --verbose --force --deep -o runtime --sign "${CODE_SIGN_IDENTITY}" "${app_path}"

if ! spctl --verbose=4 --assess --type execute "${app_path}"; then
    echo "error: Signature will not be accepted by Gatekeeper!" 1>&2
    exit 1
fi

product_name=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "${app_path}/Contents/Info.plist")
zipped_app="${product_name}.zip"

pushd "Build"

echo "Compressing ${product_name} to ${zipped_app}"
ditto -c -k --rsrc --keepParent "${app_path}" "${zipped_app}" 2>&1 > /dev/null

echo "Uploading to Apple to notarize."
set -x
notarize_uuid=$(xcrun notarytool submit "${zipped_app}" --apple-id "${APP_STORE_ID}" --keychain-profile "${KEYCHAIN_PROFILE}" --team-id "${TEAM_ID}" --wait 2>&1 | grep '^  id' | awk 'END {print $2}')
set +x
echo "Notarization info tracking id: ${notarize_uuid}"
sleep 3

progress=$(xcrun notarytool info "${notarize_uuid}" --keychain-profile "${KEYCHAIN_PROFILE}" 2>&1 |grep status | awk '{print $2'})
if [ $? -ne 0 ] || [  "${progress}" != "Accepted" ] ; then
    echo "Error with notarization. Exiting"
    xcrun notarytool info "${notarize_uuid}" --keychain-profile "${KEYCHAIN_PROFILE}"
    exit 1
fi

echo "Stapling and finishing archive packaging"
ditto -x -k --rsrc "${zipped_app}" "${ARCHIVE_PATH}/Submissions/${notarize_uuid}"
xcrun stapler staple "${ARCHIVE_PATH}/Submissions/${notarize_uuid}/Vienna.app"
plutil -insert Distributions -xml 	"<array><dict>	\
			<key>identifier</key>						\
			<string>${notarize_uuid}</string>			\
			<key>destination</key>						\
			<string>upload</string>						\
			<key>uploadDestination</key>				\
			<string>Developer ID</string>				\
			<key>processingCompletedEvent</key>			\
			<dict><key>state</key>						\
			<string>success</string>					\
			</dict>										\
		</dict></array>" "${ARCHIVE_PATH}/Info.plist"
popd
exit 0

