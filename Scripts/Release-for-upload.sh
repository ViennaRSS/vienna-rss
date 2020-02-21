#!/bin/bash

. "${SOURCE_ROOT}/build/Post-archive-exports.txt"

# Directory created during the Changes-and-Notes.sh stage
VIENNA_UPLOADS_DIR="${SOURCE_ROOT}/build/Uploads"
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

cd "${VIENNA_UPLOADS_DIR}"

# Make the dSYM Bundle
tar -czf "${dSYM_FILENAME}.tar.gz" --exclude '.DS_Store' "$ARCHIVE_DSYMS_PATH"

# Zip up the app
# Copy the app cleanly
xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE_PATH" -exportPath .
tar -czf "${TGZ_FILENAME}" --exclude '.DS_Store' Vienna.app
rm -rf Vienna.app


# Output the sparkle change log

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
		<copyright>Copyright 2010-2020, Steve Palmer and contributors</copyright>
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

# hierarchy between final releases, release candidates and betas
if [ -f "${VIENNA_UPLOADS_DIR}/changelog.xml" ]; then
	cp "${VIENNA_UPLOADS_DIR}/changelog.xml" "${VIENNA_UPLOADS_DIR}/changelog_rc.xml"
fi
if [ -f "${VIENNA_UPLOADS_DIR}/changelog_rc.xml" ]; then
	cp "${VIENNA_UPLOADS_DIR}/changelog_rc.xml" "${VIENNA_UPLOADS_DIR}/changelog_beta.xml"
fi

open "${VIENNA_UPLOADS_DIR}"
exit 0
