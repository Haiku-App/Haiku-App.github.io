require 'xcodeproj'
project_path = '/Users/reswin/Desktop/clock/clock.xcodeproj'
project = Xcodeproj::Project.open(project_path)
app_target = project.targets.find { |t| t.name == 'clock' }
clock_group = project.main_group.find_subpath('clock', false)

# Add StoreManager.swift
file_ref = clock_group.new_reference('StoreManager.swift')
app_target.source_build_phase.add_file_reference(file_ref)

# Add Products.storekit
file_ref_storekit = clock_group.new_reference('Products.storekit')
# Storekit files usually go to resources
app_target.resources_build_phase.add_file_reference(file_ref_storekit)

project.save
