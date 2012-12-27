#!/bin/bash

. "${OBJROOT}/autorevision.tmp"
BUILD_NUMBER="2821"
N_VCS_NUM="$(echo "${BUILD_NUMBER} + ${VCS_NUM}" | bc)"
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')"
VIENNA_UPLOADS_DIR="${BUILT_PRODUCTS_DIR}/Uploads"
DOWNLOAD_BASE_URL="http://sourceforge.net/projects/vienna-rss/files"
MAIN_BASE_URL="http://vienna-rss.sourceforge.net"
TGZ_FILENAME="Vienna${N_VCS_TAG}.${N_VCS_NUM}.tgz"
dSYM_FILENAME="Vienna${N_VCS_TAG}.${N_VCS_NUM}-dSYM"
if [[ "${VCS_TAG}" == *_beta* ]]; then
	VIENNA_CHANGELOG="changelog_beta.xml"
	DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL}/TestVersions"
else
	VIENNA_CHANGELOG="changelog.xml"
	DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL}/ReleasedVersions"
fi

# codesign setup
function signd {
	if [ ! -z "${CODE_SIGN_IDENTITY}" ]; then
		# Local Config
		local idetd="${CODE_SIGN_IDENTITY}"
		local resrul="${CODE_SIGN_RESOURCE_RULES_PATH}"
		local appth="${BUILT_PRODUCTS_DIR}/Vienna.app"

		# Sign and verify the app
		if [ ! -z "${idetd}" ]; then
			cp -a "${resrul}" "${appth}/ResourceRules.plist"
			codesign -f -s "${idetd}" --resource-rules="${appth}/ResourceRules.plist" -vvv "${appth}"
			rm "${appth}/ResourceRules.plist"
		else
			codesign -f -s "${idetd}" -vvv "${appth}"
		fi
		codesign -vvv --verify "${appth}"
	else
		echo "warning: No code signing identity configured; code will not be signed."
	fi
}


# Fail if not deployment
if [ ! "${CONFIGURATION}" = "Deployment" ]; then
	echo "error: This should only be run as Deployment" >&2
	exit 1
fi


cd "${BUILT_PRODUCTS_DIR}"


# Make the dSYM Bundle
mkdir -p "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"
cp -a *.dSYM "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"
cd "${VIENNA_UPLOADS_DIR}"
tar -czf "${dSYM_FILENAME}.tgz" --exclude '.DS_Store' "${dSYM_FILENAME}"
rm -rf "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"


# Zip up the app
cd "${BUILT_PRODUCTS_DIR}"
signd
tar -czf "${TGZ_FILENAME}" --exclude '.DS_Store' Vienna.app
mv "${TGZ_FILENAME}" "${VIENNA_UPLOADS_DIR}"


# Output the sparkle change log
cd "${VIENNA_UPLOADS_DIR}"
pubDate="$(LC_TIME=en_US date -jf '%FT%T%z' "${VCS_DATE}" '+%a, %d %b %G %T %z')"
TGZSIZE="$(stat -f %z "${TGZ_FILENAME}")"
cat > "${VIENNA_CHANGELOG}" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
	<channel>
		<title>Vienna Changelog</title>
		<link>http://www.vienna-rss.org/</link>
		<description>Vienna Changelog</description>
		<language>en-us</language>
		<copyright>Copyright 2010-2012, Steve Palmer and contributors</copyright>
		<item>
			<title>Vienna ${N_VCS_TAG}.${N_VCS_NUM}</title>
			<pubDate>${pubDate}</pubDate>
			<link>${DOWNLOAD_BASE_URL}/${N_VCS_TAG}/Vienna${N_VCS_TAG}.${N_VCS_NUM}.tgz/download</link>
			<sparkle:minimumSystemVersion>${MACOSX_DEPLOYMENT_TARGET}.0</sparkle:minimumSystemVersion>
			<enclosure url="${DOWNLOAD_BASE_URL}/${N_VCS_TAG}/Vienna${N_VCS_TAG}.${N_VCS_NUM}.tgz/download" sparkle:version="${N_VCS_NUM}" sparkle:shortVersionString="${N_VCS_TAG}.${N_VCS_NUM}" length="${TGZSIZE}" type="application/octet-stream"/>
			<sparkle:releaseNotesLink>${MAIN_BASE_URL}/noteson${N_VCS_TAG}.${N_VCS_NUM}.html</sparkle:releaseNotesLink>
		</item>
	</channel>
</rss>

EOF

exit 0
