WORKSPACE=Vienna.xcworkspace
SCHEME=Vienna

default:
	xcodebuild -workspace $(WORKSPACE) -scheme "Pods-Vienna" -configuration Deployment\
		CONFIGURATION_BUILD_DIR="../build" LIBRARY_SEARCH_PATHS="../build"
	xcodebuild -workspace $(WORKSPACE) -scheme "Archive and Prep for Upload" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

release:
	xcodebuild -workspace $(WORKSPACE) -scheme "Pods-Vienna" -configuration Deployment\
		CONFIGURATION_BUILD_DIR="../build" LIBRARY_SEARCH_PATHS="../build"
	xcodebuild -workspace $(WORKSPACE) -scheme "Archive and Prep for Upload" -configuration Deployment\
		CONFIGURATION_BUILD_DIR=build LIBRARY_SEARCH_PATHS="build"

development:
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration Development 

clean:
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration Development clean
	xcodebuild -workspace $(WORKSPACE) -scheme $(SCHEME) -configuration Deployment clean
	rm -fr build
	rm -fr Pods/build
