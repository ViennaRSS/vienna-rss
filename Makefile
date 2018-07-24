PROJECT=Vienna.xcodeproj
SCHEME=Vienna

default:
	xcodebuild -project $(PROJECT) -scheme "Vienna Help" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"
	xcodebuild -project $(PROJECT) -scheme "Archive and Prep for Upload" -configuration Deployment\
		-xcconfig Scripts/Resources/CS-ID.xcconfig CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

release:
	xcodebuild -project $(PROJECT) -scheme "Vienna" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"
	xcodebuild -project $(PROJECT) -scheme "Archive and Prep for Upload" -configuration Deployment\
		-xcconfig Scripts/Resources/CS-ID.xcconfig CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

development:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Development

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Development clean
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Deployment clean
	rm -fr build
	rm -fr Carthage/Build
