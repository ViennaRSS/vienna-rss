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


product_name=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "${app_path}/Contents/Info.plist")
zipped_app="${product_name}.zip"

pushd "Build"

echo "Compressing ${product_name} to ${zipped_app}"
ditto -c -k --rsrc --keepParent "${app_path}" "${zipped_app}" 2>&1 > /dev/null

uuid=$(uuidgen)
echo "Uploading to Apple to notarize. Bundle id: ${uuid}"
set -x
notarize_uuid=$(xcrun altool --notarize-app --primary-bundle-id "${uuid}" --username "${APP_STORE_ID}" --password "${APP_STORE_PASSWORD}" --team-id "${TEAM_ID}" --file "${zipped_app}" 2>&1 |grep RequestUUID | awk '{print $3'})
set +x
echo "Notarization info tracking id: ${notarize_uuid}"
sleep 3

success=0
while true; do
	progress=$(xcrun altool --notarization-info "${notarize_uuid}"  -u "${APP_STORE_ID}" -p "${APP_STORE_PASSWORD}" 2>&1 )
	echo "${progress}"

	if [ $? -ne 0 ] || [[  "${progress}" =~ "Invalid" ]] ; then
		echo "Error with notarization. Exiting"
		break
	fi

	if [[ "${progress}" =~ "success" ]]; then
		success=1
		break
	fi

	if [[ "${progress}" =~ "in progress" ]]; then
		echo "Not completed yet. Sleeping for 30 seconds"
		sleep 30
	else
		echo "Unknown error during notarization. Exiting"
		xcrun altool --notarization-info "${notarize_uuid}"  -u "${APP_STORE_ID}" -p "${APP_STORE_PASSWORD}"
		break
	fi
done


if [ $success -eq 1 ] ; then

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
else
	echo "Could not notarize"
	popd
	exit 1
fi

