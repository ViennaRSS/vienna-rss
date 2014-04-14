#!/bin/sh

# Config
export PATH=${PATH}:/sw/bin:/opt/local/bin:/usr/local/bin:/usr/local/git/bin
BUILD_NUMBER="2821"
hauto="${BUILT_PRODUCTS_DIR}/autorevision.h"
fauto="${SRCROOT}/src/autorevision.h"
xauto="${OBJROOT}/autorevision.h"
cauto="${OBJROOT}/autorevision.cache"
tauto="${OBJROOT}/autorevision.tmp"

# Check our paths
if [ ! -d "${BUILT_PRODUCTS_DIR}" ]; then
	mkdir -p "${BUILT_PRODUCTS_DIR}"
fi
if [ ! -d "${OBJROOT}" ]; then
	mkdir -p "${OBJROOT}"
fi


if ! ./3rdparty/autorevision/autorevision -o "${cauto}" -t sh; then
	exit ${?}
fi


# Source the initial autorevision output for filtering.
. "${cauto}"


# Filter the output.

N_VCS_NUM="$(echo "${BUILD_NUMBER} + ${VCS_NUM}" | bc)"

# Prettify the branch name
N_VCS_BRANCH="$(echo "${VCS_BRANCH}" | sed -e 's:remotes/:remote/:' -e 's:/:-:' -e 's:master:Master:')"

if [[ ! "${VCS_TICK}" = "0" ]] && [[ ! -z "${VCS_BRANCH}" ]]; then
	# If we are not exactly on a tag try using the branch name instead
	sed -e "s:${VCS_TAG}:${N_VCS_BRANCH}:" -e "s:${VCS_BRANCH}:${N_VCS_BRANCH}:" -e "s:${VCS_NUM}:${N_VCS_NUM}:" "${cauto}" > "${tauto}"
else
	# Prettify the tag name
	N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::' | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')"
	sed -e "s:${VCS_TAG}:${N_VCS_TAG}:" -e "s:${VCS_BRANCH}:${N_VCS_BRANCH}:" -e "s:${VCS_NUM}:${N_VCS_NUM}:" "${cauto}" > "${tauto}"
fi


# Output for src/autorevision.h.
./3rdparty/autorevision/autorevision -f -o "${cauto}" -t h > "${hauto}"
if [[ ! -f "${fauto}" ]] || ! cmp -s "${hauto}" "${fauto}"; then
	cp -a "${hauto}" "${fauto}"
fi

# Output for info.plist prepossessing.
./3rdparty/autorevision/autorevision -f -o "${tauto}" -t xcode > "${xauto}"

exit ${?}
