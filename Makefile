PROJECT=Vienna.xcodeproj
LOCALES=cs da de es eu fr gl it ja ko lt nl pt-BR pt ru sv tr uk zh-Hans zh-Hant

default:
	xcodebuild -project $(PROJECT) -scheme "Vienna Help" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"
	xcodebuild -project $(PROJECT) -scheme "Deployment" -configuration Deployment\
		-xcconfig Scripts/Resources/CS-ID.xcconfig CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

release:
	xcodebuild -project $(PROJECT) -scheme "Vienna" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"
	xcodebuild -project $(PROJECT) -scheme "Deployment" -configuration Deployment\
		-xcconfig Scripts/Resources/CS-ID.xcconfig CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

development:
	xcodebuild -project $(PROJECT) -scheme "Vienna" -configuration Development

clean:
	xcodebuild -project $(PROJECT) -scheme "Vienna" -configuration Development clean
	xcodebuild -project $(PROJECT) -scheme "Vienna" -configuration Deployment clean
	rm -fr build
	rm -fr Carthage/Build

localize:
	for locale in $(LOCALES); do \
		xcodebuild -importLocalizations -project $(PROJECT) -localizationPath "Localizations/$${locale}.xliff"; \
	done
