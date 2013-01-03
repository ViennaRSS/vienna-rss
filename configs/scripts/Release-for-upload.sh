#!/bin/bash

. "${OBJROOT}/autorevision.tmp"
BUILD_NUMBER="2821" # Magic number; do not touch!
N_VCS_NUM="$(echo "${BUILD_NUMBER} + ${VCS_NUM}" | bc)"
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')" # for urls/files
V_VCS_TAG="$(echo "${N_VCS_TAG}" | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')" # for display
VIENNA_UPLOADS_DIR="${BUILT_PRODUCTS_DIR}/Uploads"
DOWNLOAD_BASE_URL="${BASE_URL_TYP}://${BASE_URL_LOC}" # values set in project-all.xcconfig
TGZ_FILENAME="Vienna${N_VCS_TAG}.tgz"
dSYM_FILENAME="Vienna${N_VCS_TAG}.${VCS_SHORT_HASH}-dSYM"
case "${N_VCS_TAG}" in
	*_beta*)
		VIENNA_CHANGELOG="changelog_beta.xml"
		DOWNLOAD_SUB_DIR="TestVersions"
	;;
	*_rc*)
		VIENNA_CHANGELOG="changelog_rc.xml"
		DOWNLOAD_SUB_DIR="TestVersions"
	;;
	*)
		VIENNA_CHANGELOG="changelog.xml"
		DOWNLOAD_SUB_DIR="ReleasedVersions"
	;;
esac
DOWNLOAD_TAG_DIR="${N_VCS_TAG}"
DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL}/${DOWNLOAD_SUB_DIR}/${DOWNLOAD_TAG_DIR}"

# codesign setup
function signd {
	if [ ! -z "${CODE_SIGN_IDENTITY}" ]; then
		# Local Config
		local appth="${1}"
		local idetd="${CODE_SIGN_IDENTITY}"
		local resrul="${CODE_SIGN_RESOURCE_RULES_PATH}"
		local csreq="${CODE_SIGN_REQUIREMENTS_PATH}"

		# Sign and verify the app
		if [[ ! -z "${resrul}" ]] && [[ ! -z "${csreq}" ]]; then
			cp -a "${resrul}" "${appth}/ResourceRules.plist"
			codesign -f --sign "${idetd}" --resource-rules="${appth}/ResourceRules.plist" --requirements "${csreq}" -vvv "${appth}"
			rm "${appth}/ResourceRules.plist"
		else
			codesign -f --sign "${idetd}" --requirements "${csreq}" -vvv "${appth}"
		fi
		if ! codesign -vvv --verify "${appth}"; then
			echo "warning: Code is improperly signed!" 1>&2
		fi
	else
		echo "warning: No Code Signing Identity configured or no Code Signing Requirement configured; code will not be signed." 1>&2
	fi
}


# Fail if not deployment
if [ ! "${CONFIGURATION}" = "Deployment" ]; then
	echo "error: This should only be run as Deployment" >&2
	exit 1
fi
# Fail if incorrectly tagged
if [[ VCS_TICK == "0" ]] && ! git describe --exact-match "${VCS_TAG}"; then
	echo 'error: The tag is not annotated; please redo the tag with `git tag -s` or `git tag -a`.' 1>&2
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
cd "${VIENNA_UPLOADS_DIR}"
# Copy the app cleanly
rsync -clprt --del --exclude=".DS_Store" "${BUILT_PRODUCTS_DIR}/Vienna.app" "${VIENNA_UPLOADS_DIR}"
signd "Vienna.app"
tar -czf "${TGZ_FILENAME}" --exclude '.DS_Store' Vienna.app
rm -rf Vienna.app


# Output the sparkle change log
cd "${VIENNA_UPLOADS_DIR}"

pubDate="$(LC_TIME=en_US date -jf '%FT%T%z' "${VCS_DATE}" '+%a, %d %b %G %T %z')"
TGZSIZE="$(stat -f %z "${TGZ_FILENAME}")"
SIGNATURE=$("${PROJECT_DIR}/signing/sign_update.rb" "${TGZ_FILENAME}" "${PRIVATE_KEY_PATH}")

if [ -z "${SIGNATURE}" ]; then
	echo "warning: Unable to load signing private key vienna_private_key.pem. Set PRIVATE_KEY_PATH in CS-ID.xcconfig" 1>&2
fi

cat > "${VIENNA_CHANGELOG}" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
	<channel>
		<title>Vienna Changelog</title>
		<link>http://www.vienna-rss.org/</link>
		<description>Vienna Changelog</description>
		<language>en-us</language>
		<copyright>Copyright 2010-2013, Steve Palmer and contributors</copyright>
		<item>
			<title>Vienna ${V_VCS_TAG} :${VCS_SHORT_HASH}:</title>
			<pubDate>${pubDate}</pubDate>
			<link>${DOWNLOAD_BASE_URL}/${TGZ_FILENAME}</link>
			<sparkle:minimumSystemVersion>${MACOSX_DEPLOYMENT_TARGET}.0</sparkle:minimumSystemVersion>
			<enclosure url="${DOWNLOAD_BASE_URL}/${TGZ_FILENAME}" sparkle:version="${N_VCS_NUM}" sparkle:shortVersionString="${V_VCS_TAG} :${VCS_SHORT_HASH}:" length="${TGZSIZE}" sparkle:dsaSignature="${SIGNATURE}" type="application/octet-stream"/>
			<sparkle:releaseNotesLink>http://vienna-rss.org/noteson${N_VCS_TAG}.html</sparkle:releaseNotesLink>
		</item>
	</channel>
</rss>

EOF

exit 0
