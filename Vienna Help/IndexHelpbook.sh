#!/bin/bash

# Config
lprojDir="${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
lprojList=$(\ls -1 "${lprojDir}" | sed -n 's:\.lproj$:&:p' | sed -e 's:\.lproj::')


# Copy and index the help files.
for lang in ${lprojList}; do
	helpDir="${lprojDir}/${lang}.lproj/"
  
	echo "Indexing help book for ${lang} ..."
	case "${lang}" in
		ja|ko|zh_CN|zh_TW)
			MIN_TERM="1"
		;;
		*)
			MIN_TERM="3"
	esac
	case "${lang}" in
		en|de|es|fr|sv|hu|it)
			STOP_WORDS="--stopwords ${lang}"
		;;
		*)
			STOP_WORDS=""
	esac
    pushd "${helpDir}"
    # Spotlight help format required for macOS Mojave (10.14) or later
    /usr/bin/hiutil --create --anchors --index-format corespotlight --min-term-length="${MIN_TERM}" ${STOP_WORDS} --file "${PRODUCT_NAME}.cshelpindex" -vv .
    # Latent Symantic Mapping (LSM) help format for versions prior to Mojave
    /usr/bin/hiutil --create --anchors --index-format lsm --min-term-length="${MIN_TERM}" ${STOP_WORDS} --file "${PRODUCT_NAME}.helpindex" -vv .
    # control
    /usr/bin/hiutil -T --index-format corespotlight --file "${PRODUCT_NAME}.cshelpindex" -v
    popd
done

exit 0
