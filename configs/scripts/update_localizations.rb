#!/usr/bin/env ruby
#
#  update_localizations.rb
#  Vienna
#
#  Copyright 2017
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  https://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

unless system('which xcodebuild 1>/dev/null')
    raise 'This script requires xcodebuild'
end

unless ENV.has_key?('PROJECT_DIR')
    raise 'Environment variable PROJECT_DIR not set'
end

unless ENV.has_key?('PROJECT_FILE_PATH')
    raise 'Environment variable PROJECT_FILE_PATH not set'
end

xliff_dir = File.join(ENV['PROJECT_DIR'], "Localizations/")

unless Dir.exists?(xliff_dir)
    raise "Directory #{xliff_dir} not found"
end

xcode_project = ENV['PROJECT_FILE_PATH']

xliff_files = Dir.entries(xliff_dir).select { |f| File.extname(f) == '.xliff' unless f == 'en.xliff' }
xliff_files.collect! { |f| File.join(xliff_dir, f) }
puts xliff_files

# Import files
xliff_files.each do |f|
    puts "Import #{File.basename(f)}"

    `xcodebuild -importLocalizations -project #{xcode_project} -localizationPath #{f} 2>/dev/null`
    warn "xcodebuild reported a problem while importing #{File.basename(f)}" unless $?.success?
end

# Export files
puts 'Export localizations'

languages = xliff_files.collect { |f| File.basename(f, '.*') }
arguments = languages.collect { |f| "-exportLanguage #{f}" }.join(' ')

`xcodebuild -exportLocalizations -project #{xcode_project} -localizationPath #{xliff_dir} #{arguments} 2>/dev/null`
warn 'xcodebuild encountered a problem while exporting' unless $?.success?
