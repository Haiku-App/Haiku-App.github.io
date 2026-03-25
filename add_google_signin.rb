require 'xcodeproj'

project_path = '/Users/reswin/Desktop/clock/clock.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'clock' }

# 1. Add Swift Package Dependency: GoogleSignIn-iOS
package_url = 'https://github.com/google/GoogleSignIn-iOS.git'
unless project.root_object.package_references.find { |pr| pr.repositoryURL == package_url }
  # Add the XCRemoteSwiftPackageReference
  pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
  pkg_ref.repositoryURL = package_url
  pkg_ref.requirement = {
    'kind' => 'upToNextMajorVersion',
    'minimumVersion' => '7.1.0'
  }
  project.root_object.package_references << pkg_ref

  # Add the XCSwiftPackageProductDependency to the target
  pkg_prod = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
  pkg_prod.package = pkg_ref
  pkg_prod.product_name = 'GoogleSignIn'
  
  app_target.package_product_dependencies << pkg_prod
end

# 2. Add Info.plist to the clock group and configure it
info_plist_path = File.join('/Users/reswin/Desktop/clock', 'clock', 'Info.plist')
unless File.exist?(info_plist_path)
  File.open(info_plist_path, 'w') do |f|
    f.write(<<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleURLTypes</key>
          <array>
              <dict>
                  <key>CFBundleTypeRole</key>
                  <string>Editor</string>
                  <key>CFBundleURLSchemes</key>
                  <array>
                      <string>com.googleusercontent.apps.313459507705-1k57s4u6ejhm8kl5c93ql4hu5th2r0eq</string>
                  </array>
              </dict>
          </array>
          <key>GIDClientID</key>
          <string>313459507705-1k57s4u6ejhm8kl5c93ql4hu5th2r0eq.apps.googleusercontent.com</string>
      </dict>
      </plist>
    PLIST
    )
  end
end

# Ensure INFOPLIST_FILE build setting is set
app_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'clock/Info.plist'
end

project.save
puts "Successfully added GoogleSignIn SPM dependency and Info.plist."
