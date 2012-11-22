#!/bin/bash

# Config
scriptDir="./configs/scripts/help"
lprojDir="./lproj"
lprojList=$(\ls -1 ${lprojDir} | sed -n 's:\.lproj$:&:p' | sed -e 's:\.lproj::')


# Copy and index the help files.
for lang in ${lprojList}; do
	helpDir="${lprojDir}/${lang}.lproj/Vienna Help"
	bundleDir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/${lang}.lproj"
	if [[ -d "${helpDir}" ]] && [[ -d "${bundleDir}" ]]; then
		echo "Setting up for ${lang} ..."
		cp -a "${helpDir}" "${bundleDir}"
		. "${scriptDir}/${lang}.sh"
	fi
done

exit 0
