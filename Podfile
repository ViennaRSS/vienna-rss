platform :osx, '10.9'
source 'https://github.com/CocoaPods/Specs.git'

target 'Vienna' do
	pod 'MASPreferences', '~> 1.1.4'
	pod 'ASIHTTPRequest', '~> 1.8', :inhibit_warnings => true
	pod 'FMDB', '~> 2.7.2'
	pod 'Sparkle', '~> 1.17.0'
end

target 'Vienna Tests' do
	pod 'FMDB', '~> 2.7.2'
	pod 'Sparkle', '~> 1.17.0'
	pod 'OCMock'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
