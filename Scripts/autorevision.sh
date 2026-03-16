#!/bin/sh

# Config
export PATH=/sw/bin:/opt/local/bin:/usr/local/bin:/usr/local/git/bin:${PATH}
BUILD_NUMBER="2821"
intermediateHeaderOutput="/tmp/autorevision.h"
finalHeaderOutput="${SRCROOT}/Vienna/Sources/autorevision.h"
plistHeaderOutput="${OBJROOT}/autorevision.plist.h"
cacheOutput="${OBJROOT}/autorevision.cache"
tempCacheOutput="/tmp/autorevision.tmp"

# Check our paths
if [ ! -d "${BUILT_PRODUCTS_DIR}" ]; then
	mkdir -p "${BUILT_PRODUCTS_DIR}"
fi
if [ ! -d "${OBJROOT}" ]; then
	mkdir -p "${OBJROOT}"
fi


if ! ./External/autorevision/autorevision -o "${cacheOutput}" -t sh; then
	exit ${?}
fi


# Output for Vienna/Sources/autorevision.h.
# This header might be useful for including in code, (currently Vienna does not use it)
# Be warned however that the VCS_NUM set will not reflect the reality, because of historical issues in Vienna
./External/autorevision/autorevision -f -o "${cacheOutput}" -t h > "${intermediateHeaderOutput}"
if [ ! -f "${finalHeaderOutput}" ] || ! cmp -s "${intermediateHeaderOutput}" "${finalHeaderOutput}"; then
	mv "${intermediateHeaderOutput}" "${finalHeaderOutput}"
fi


# Source the initial autorevision output for filtering.
. "${cacheOutput}"

# Filter the output.

N_VCS_NUM="$((BUILD_NUMBER + VCS_NUM))"

# Prettify the branch name
N_VCS_BRANCH="$(echo "${VCS_BRANCH}" | sed -e 's:remotes/:remote/:' -e 's:/:-:' -e 's:master:Master:')"

if [ ! "${VCS_TICK}" = "0" ] && [ ! -z "${VCS_BRANCH}" ]; then
	# If we are not exactly on a tag try using the branch name instead
	sed -e "s:${VCS_TAG}:${N_VCS_BRANCH}:" -e "s:${VCS_BRANCH}:${N_VCS_BRANCH}:" -e "s:${VCS_NUM}:${N_VCS_NUM}:" "${cacheOutput}" > "${tempCacheOutput}"
else
	# Prettify the tag name
	N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::' | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')"
	sed -e "s:${VCS_TAG}:${N_VCS_TAG}:" -e "s:${VCS_BRANCH}:${N_VCS_BRANCH}:" -e "s:${VCS_NUM}:${N_VCS_NUM}:" "${cacheOutput}" > "${tempCacheOutput}"
fi

# Output for info.plist prepossessing.
# This is not suitable for including in code, only for info.plist
# processing.
./External/autorevision/autorevision -f -o "${tempCacheOutput}" -t xcode > "${plistHeaderOutput}"

exit ${?}
