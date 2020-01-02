#!/bin/bash

. "${OBJROOT}/autorevision.cache"
# Magic number; do not touch!
BUILD_NUMBER="2821"
N_VCS_NUM="$((BUILD_NUMBER + VCS_NUM))"

# for urls/files
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')"
# for display
V_VCS_TAG="$(echo "${N_VCS_TAG}" | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')"

VIENNA_UPLOADS_DIR="${BUILT_PRODUCTS_DIR}/Uploads"
DOWNLOAD_BASE_URL="${BASE_URL_TYP}://${BASE_URL_LOC}"

TGZ_FILENAME="Vienna${N_VCS_TAG}.tar.gz"
dSYM_FILENAME="Vienna${N_VCS_TAG}.${VCS_SHORT_HASH}-dSYM"

case "${N_VCS_TAG}" in
	*_beta*)
		VIENNA_CHANGELOG="changelog_beta.xml"
	;;
	*_rc*)
		VIENNA_CHANGELOG="changelog_rc.xml"
	;;
	*)
		VIENNA_CHANGELOG="changelog.xml"
	;;
esac

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


cd "${BUILT_PRODUCTS_DIR}"


# Make the dSYM Bundle
mkdir -p "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"
cp -a ./*.dSYM "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"
cd "${VIENNA_UPLOADS_DIR}"
tar -czf "${dSYM_FILENAME}.tar.gz" --exclude '.DS_Store' "${dSYM_FILENAME}"
rm -rf "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"


# Zip up the app
cd "${VIENNA_UPLOADS_DIR}"
# Copy the app cleanly
rsync -clprt --del --exclude=".DS_Store" "${BUILT_PRODUCTS_DIR}/Vienna.app" "${VIENNA_UPLOADS_DIR}"
tar -czf "${TGZ_FILENAME}" --exclude '.DS_Store' Vienna.app
rm -rf Vienna.app


# Output the sparkle change log
cd "${VIENNA_UPLOADS_DIR}"

pubDate="$(LC_TIME=en_US TZ=GMT date -jf '%FT%TZ' "${VCS_DATE}" '+%a, %d %b %G %T %z')"
TGZSIZE="$(stat -f %z "${TGZ_FILENAME}")"
SIGNATURE=$("${PROJECT_DIR}/Scripts/sign_update.rb" "${TGZ_FILENAME}" "${PRIVATE_KEY_PATH}")

if [ -z "${SIGNATURE}" ]; then
	echo "warning: Unable to load signing private key vienna_private_key.pem. Set PRIVATE_KEY_PATH in Scripts/Resources/CS-ID.xcconfig" 1>&2
fi

cat > "${VIENNA_CHANGELOG}" << EOF
<?xml version="1.0" encoding="UTF-8" ?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
	<channel>
		<title>Vienna Changelog</title>
		<link>http://www.vienna-rss.com/</link>
		<description>Vienna Changelog</description>
		<language>en-us</language>
		<copyright>Copyright 2010-2015, Steve Palmer and contributors</copyright>
		<item>
			<title>Vienna ${V_VCS_TAG} :${VCS_SHORT_HASH}:</title>
			<pubDate>${pubDate}</pubDate>
			<link>${DOWNLOAD_BASE_URL}/${TGZ_FILENAME}</link>
			<sparkle:minimumSystemVersion>${MACOSX_DEPLOYMENT_TARGET}.0</sparkle:minimumSystemVersion>
			<enclosure url="${DOWNLOAD_BASE_URL}/${TGZ_FILENAME}" sparkle:version="${N_VCS_NUM}" sparkle:shortVersionString="${V_VCS_TAG} :${VCS_SHORT_HASH}:" length="${TGZSIZE}" sparkle:dsaSignature="${SIGNATURE}" type="application/octet-stream"/>
			<sparkle:releaseNotesLink>https://viennarss.github.io/sparkle-files/noteson${N_VCS_TAG}.html</sparkle:releaseNotesLink>
		</item>
	</channel>
</rss>

EOF

exit 0
