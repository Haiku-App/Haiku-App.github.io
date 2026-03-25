require 'xcodeproj'

project_path = '/Users/reswin/Desktop/clock/clock.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
target_name = 'clockWidgetExtension'
existing_target = project.targets.find { |t| t.name == target_name }
if existing_target
  puts "Target already exists."
  exit 0
end

# Find the main app target to embed the extension
app_target = project.targets.find { |t| t.name == 'clock' }

# Create the widget extension target
widget_target = project.new_target(:app_extension, target_name, :ios, '17.0')
widget_target.product_name = 'clockWidgetExtension'
widget_target.product_reference.name = 'clockWidgetExtension.appex'

# Set Build Settings
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'reswin.clock.clockWidget'
  config.build_settings['INFOPLIST_FILE'] = 'clockWidget/Info.plist'
  config.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  config.build_settings['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['DEVELOPMENT_TEAM'] = app_target.build_configurations.first.build_settings['DEVELOPMENT_TEAM'] || ''
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = ''
end

# Add the clockWidget group if it doesn't exist
group = project.main_group.find_subpath(File.join('clockWidget'), true)
group.set_source_tree('<group>')
group.set_path('clockWidget')

# Add swift file to group and target
file_ref = group.new_reference('clockWidget.swift')
widget_target.source_build_phase.add_file_reference(file_ref)

# Add existing files to the widget target
%w[StaticClockView.swift ClockDrawing.swift ClockTask.swift ClockModels.swift].each do |file_name|
  file_ref = project.main_group.find_subpath('clock', false).children.find { |c| c.name == file_name || c.path == file_name }
  if file_ref
    widget_target.source_build_phase.add_file_reference(file_ref)
  end
end

# Add Assets.xcassets to widget target
assets_ref = project.main_group.find_subpath('clock', false).children.find { |c| c.path == 'Assets.xcassets' }
if assets_ref
  widget_target.resources_build_phase.add_file_reference(assets_ref)
end

# Create Info.plist for widget
info_plist_path = File.join('/Users/reswin/Desktop/clock', 'clockWidget', 'Info.plist')
unless File.exist?(info_plist_path)
  File.open(info_plist_path, 'w') do |f|
    f.write(<<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>NSExtension</key>
          <dict>
              <key>NSExtensionPointIdentifier</key>
              <string>com.apple.widgetkit-extension</string>
          </dict>
      </dict>
      </plist>
    PLIST
    )
  end
end
info_plist_ref = group.new_reference('Info.plist')

# Embed the widget extension into the main app target
project.targets.each do |t|
  if t.name == 'clock'
    embed_phase = t.new_copy_files_build_phase('Embed Foundation Extensions')
    embed_phase.symbol_dst_subfolder_spec = :plug_ins
    build_file = embed_phase.add_file_reference(widget_target.product_reference)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
end

project.save
puts "Successfully added widget target to Xcode project."
