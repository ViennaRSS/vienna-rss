#!/bin/sh

. "${OBJROOT}/autorevision.cache"
N_VCS_TAG="$(echo "${VCS_TAG}" | sed -e 's:^v/::')"
VIENNA_UPLOADS_DIR="${BUILT_PRODUCTS_DIR}/Uploads"
VIENNA_NOTES="${SRCROOT}/notes.html"


# Fail if not deployment
if [ ! "${CONFIGURATION}" = "Deployment" ]; then
	echo "error: This should only be run as Deployment" >&2
	exit 1
fi

echo "Running script to create web site files"
if [ ! -d "${VIENNA_UPLOADS_DIR}" ] ; then
	mkdir "${VIENNA_UPLOADS_DIR}"
else
	rm -fr "${VIENNA_UPLOADS_DIR}"/*
fi

cd "${VIENNA_UPLOADS_DIR}"

if [ -f "${VIENNA_NOTES}" ] ; then
	cp -a "${VIENNA_NOTES}" "noteson${N_VCS_TAG}.html"
fi

exit 0
