#!/bin/bash

# Config
lprojDir="./Vienna/Vienna.help/Contents/Resources"
lprojList=$(\ls -1 ${lprojDir} | sed -n 's:\.lproj$:&:p' | sed -e 's:\.lproj::')


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
			/usr/bin/hiutil -C -avv -m "${MIN_TERM}" -s "${lang}" -f "${helpDir}/Vienna.helpindex" "${helpDir}"
		;;
		*)
			/usr/bin/hiutil -C -avv -m "${MIN_TERM}" -f "${helpDir}/Vienna.helpindex" "${helpDir}"
	esac
done

exit 0
