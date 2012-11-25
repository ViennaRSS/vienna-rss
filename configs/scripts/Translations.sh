#!/bin/bash

# Config
lprojDir="./lproj"
lprojList=$(\ls -1 ${lprojDir} | sed -n 's:\.lproj$:&:p' | sed -e 's:\.lproj::')


# Copy and index the help files.
for lang in ${lprojList}; do
	helpDir="${lprojDir}/${lang}.lproj/Vienna Help"
	bundleDir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/${lang}.lproj"
	bunHelpDir="${bundleDir}/Vienna Help"
	if [[ -d "${helpDir}" ]] && [[ -d "${bundleDir}" ]]; then
		echo "Setting up for ${lang} ..."
		rm -fr "${bunHelpDir}"
		cp -a "${helpDir}" "${bundleDir}"
		case "${lang}" in
			ja|ko|zh_CN|zh_TW)
				MIN_TERM="1"
			;;
			*)
				MIN_TERM="3"
		esac
		case "${lang}" in
			en|de|es|fr|sv|hu|it)
				/usr/bin/hiutil -C -avv -m "${MIN_TERM}" -s "${lang}" -f "${bunHelpDir}/Vienna Help.helpindex" "${bunHelpDir}"
			;;
			*)
				/usr/bin/hiutil -C -avv -m "${MIN_TERM}" -f "${bunHelpDir}/Vienna Help.helpindex" "${bunHelpDir}"
		esac
	fi
done

exit 0
