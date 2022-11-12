#!/bin/bash

. "${OBJROOT}/autorevision.cache"
# Magic number; do not touch!
BUILD_NUMBER="2821"
N_VCS_NUM="$((BUILD_NUMBER + VCS_NUM))"

# for urls/files
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')"
# for display
V_VCS_TAG="$(echo "${N_VCS_TAG}" | sed -e 's:_beta: Beta :' -e 's:_rc: RC :')"


OUT_FILE="${SOURCE_ROOT}/Build/Post-archive-exports.txt"


rm "${OUT_FILE}"
echo export ARCHIVE_PATH="\"${ARCHIVE_PATH}\"" > "${OUT_FILE}"
echo export ARCHIVE_DSYMS_PATH="\"${ARCHIVE_DSYMS_PATH}\"" >> "${OUT_FILE}"
echo export SOURCE_ROOT="\"${SOURCE_ROOT}\"" >> "${OUT_FILE}"
echo export N_VCS_NUM="\"${N_VCS_NUM}\"" >> "${OUT_FILE}"
echo export N_VCS_TAG="\"${N_VCS_TAG}\"" >> "${OUT_FILE}"
echo export V_VCS_TAG="\"${V_VCS_TAG}\"" >> "${OUT_FILE}"
echo export VCS_SHORT_HASH="\"${VCS_SHORT_HASH}\"" >> "${OUT_FILE}"
echo export VCS_DATE="\"${VCS_DATE}\"" >> "${OUT_FILE}"

cp "$OUT_FILE" "$ARCHIVE_PATH"
