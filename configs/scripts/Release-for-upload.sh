#!/bin/bash

. "${OBJROOT}/autorevision.cache"
# Magic number; do not touch!
BUILD_NUMBER="2821"
N_VCS_NUM="$((BUILD_NUMBER + VCS_NUM))"

# for urls/files
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')"
# for display
V_VCS_TAG="$(echo "${N_VCS_TAG}" | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')"

# values set in project-all.xcconfig
VIENNA_UPLOADS_DIR="${BUILT_PRODUCTS_DIR}/Uploads"
DOWNLOAD_BASE_URL="${BASE_URL_TYP}://${BASE_URL_LOC}"

TGZ_FILENAME="Vienna${N_VCS_TAG}.tgz"
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

# codesign setup
function signd {
	if [[ ! -z "${CODE_SIGN_IDENTITY}" ]] && [[ ! -z ${CODE_SIGN_REQUIREMENTS_PATH} ]]; then
		# Local Config
		local appth="${1}"
		local idetd="${CODE_SIGN_IDENTITY}"
		local resrul="${CODE_SIGN_RESOURCE_RULES_PATH}"
		local csreq="${CODE_SIGN_REQUIREMENTS_PATH}"
		if [ ! -d "${DERIVED_FILES_DIR}" ]; then
			mkdir -p "${DERIVED_FILES_DIR}"
		fi

		# Verify and sign the frameworks
		local fsignd=''
		unset CLICOLOR_FORCE
		local framelst="$(\ls -1 "${appth}/Contents/Frameworks" | sed -n 's:.framework$:&:p')"
		for fsignd in ${framelst}; do
			local framepth="${appth}/Contents/Frameworks/${fsignd}/Versions/A"
			local signvs="$(/usr/bin/codesign -dv "${framepth}" 2>&1 | grep "Sealed Resources" | sed 's:Sealed Resources version=::' | cut -d ' ' -f 1)"
			if [[ -d "${framepth}" ]]; then
				local frmcsreq="${DERIVED_FILES_DIR}/${fsignd}.rqset"
				local frmid="$(defaults read "${framepth}/Resources/Info.plist" CFBundleIdentifier)"
				if ! /usr/bin/codesign --verify -vvv "${framepth}" || [ ! "${signvs}" = "2" ]; then
					# Sign if the verification fails or if the version is not 2
					
					sed -e "s:uk.co.opencommunity.vienna2:${frmid}:" "${csreq}" > "${frmcsreq}"
					
					/usr/bin/codesign -f --sign "${idetd}" --requirements "${frmcsreq}" --preserve-metadata=entitlements -vvv "${framepth}"
					if ! /usr/bin/codesign --verify -vvv "${framepth}"; then
						echo "warning: ${fsignd} is not properly signed." 1>&2
					fi
				fi
			fi
		done

		# Sign and verify the app
		if [ ! -z "${resrul}" ]; then
			cp -a "${resrul}" "${appth}/ResourceRules.plist"
			/usr/bin/codesign -f --sign "${idetd}" --resource-rules="${appth}/ResourceRules.plist" --requirements "${csreq}" -vvv "${appth}"
			rm "${appth}/ResourceRules.plist"
		else
			/usr/bin/codesign -f --sign "${idetd}" --requirements "${csreq}" -vvv "${appth}"
		fi
		if ! codesign --verify -vvv "${appth}"; then
			echo "warning: Code is improperly signed!" 1>&2
		fi
		if ! spctl --verbose=4 --assess --type execute "${appth}"; then
			echo "error: Signature will not be accepted by Gatekeeper!" 1>&2
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
tar -czf "${dSYM_FILENAME}.tgz" --exclude '.DS_Store' "${dSYM_FILENAME}"
rm -rf "${VIENNA_UPLOADS_DIR}/${dSYM_FILENAME}"


# Zip up the app
cd "${VIENNA_UPLOADS_DIR}"
# Copy the app cleanly
rsync -clprt --del --exclude=".DS_Store" "${BUILT_PRODUCTS_DIR}/Vienna.app" "${VIENNA_UPLOADS_DIR}"
signd "${VIENNA_UPLOADS_DIR}/Vienna.app"
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
		<copyright>Copyright 2010-2014, Steve Palmer and contributors</copyright>
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
