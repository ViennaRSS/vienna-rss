#!/bin/sh

# Config
. "${OBJROOT}/autorevision.tmp"
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')" # for urls/files
V_VCS_TAG="$(echo "${N_VCS_TAG}" | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')" # for display

case "${N_VCS_TAG}" in
	*_beta*)
		SU_FEED_URL="http://vienna-rss.org/changelog_beta.xml"
	;;
	*_rc*)
		SU_FEED_URL="http://vienna-rss.org/changelog_rc.xml"
	;;
	*)
		SU_FEED_URL="http://vienna-rss.org/changelog.xml"
	;;
esac

INFO="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/../Info.plist"

/usr/libexec/PlistBuddy $INFO -c "add SUFeedURL string $SU_FEED_URL"
/usr/libexec/PlistBuddy $INFO -c "set :SUFeedURL $SU_FEED_URL"
exit ${?}
