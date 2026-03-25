require 'xcodeproj'
project_path = '/Users/reswin/Desktop/clock/clock.xcodeproj'
project = Xcodeproj::Project.open(project_path)
app_target = project.targets.find { |t| t.name == 'clock' }
widget_target = project.targets.find { |t| t.name == 'clockWidgetExtension' }
clock_group = project.main_group.find_subpath('clock', false)
file_ref = clock_group.new_reference('SharedTaskManager.swift')
app_target.source_build_phase.add_file_reference(file_ref)
widget_target.source_build_phase.add_file_reference(file_ref) if widget_target
project.save
