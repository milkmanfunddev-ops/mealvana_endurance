#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds the RunnerUITests UI test target to ios/Runner.xcodeproj for Patrol.
#
# This script is idempotent — re-running it is a no-op if the target already exists.
#
# Usage (xcodeproj gem must be installed):
#   ruby scripts/add_patrol_uitest_target.rb
#
# What it does:
#   - Adds a new RunnerUITests UI test target
#   - Mirrors all build configurations from Runner (dev-Debug, dev-Profile,
#     dev-Release, prod-Debug, prod-Profile, prod-Release, and any plain ones)
#   - Adds RunnerUITests.m to the target's compile sources
#   - Sets TEST_TARGET_NAME = Runner so xcodebuild knows which app to host
#   - Adds the target as a dependency of Runner
#   - Adds a test action referencing RunnerUITests to Runner, dev, and prod
#     shared schemes so `xcodebuild test -scheme <flavor>` will run it.

require 'xcodeproj'
require 'fileutils'

PROJECT_PATH = File.expand_path('../ios/Runner.xcodeproj', __dir__)
TARGET_NAME = 'RunnerUITests'
SOURCE_DIR_NAME = 'RunnerUITests'
HOST_TARGET_NAME = 'Runner'
APP_BUNDLE_ID = 'com.milkman.mealvanaendurance'
TEST_BUNDLE_ID = "#{APP_BUNDLE_ID}.RunnerUITests"
DEPLOYMENT_TARGET = '16.6'
SWIFT_VERSION = '5.0'

abort "Project not found at #{PROJECT_PATH}" unless Dir.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "[skip] Target '#{TARGET_NAME}' already exists. Nothing to do."
  exit 0
end

host_target = project.targets.find { |t| t.name == HOST_TARGET_NAME }
abort "Host target '#{HOST_TARGET_NAME}' not found" unless host_target

# 1. Create the new UI test target.
ui_test_target = project.new_target(
  :ui_test_bundle,
  TARGET_NAME,
  :ios,
  DEPLOYMENT_TARGET,
)
puts "[ok] Created UI test target '#{TARGET_NAME}'"

# 2. Mirror every build configuration from the host target.
#    By default, new_target creates only Debug/Release. We need all flavors.
host_config_names = host_target.build_configurations.map(&:name)
existing_config_names = ui_test_target.build_configurations.map(&:name)

host_config_names.each do |name|
  next if existing_config_names.include?(name)

  host_config = host_target.build_configurations.find { |c| c.name == name }
  template = ui_test_target.build_configurations.first
  new_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  new_config.name = name
  # Copy template settings, then override.
  new_config.build_settings = template.build_settings.dup
  # Match the host's "type" (Debug/Release) by inspecting the host config.
  new_config.base_configuration_reference = nil
  ui_test_target.build_configuration_list.build_configurations << new_config
  puts "[ok] Added build configuration '#{name}'"
end

# Now remove the default Debug/Release if they don't match host configs (we
# only want configs that match host).
ui_test_target.build_configurations.dup.each do |config|
  unless host_config_names.include?(config.name)
    ui_test_target.build_configuration_list.build_configurations.delete(config)
    puts "[ok] Removed extraneous config '#{config.name}'"
  end
end

# 3. Set required build settings on every configuration.
ui_test_target.build_configurations.each do |config|
  s = config.build_settings
  s['INFOPLIST_FILE'] = "#{SOURCE_DIR_NAME}/Info.plist"
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = TEST_BUNDLE_ID
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['TEST_TARGET_NAME'] = HOST_TARGET_NAME
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
  s['SWIFT_VERSION'] = SWIFT_VERSION
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  s['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  # Don't strip our own bitcode in release-style builds.
  s['ENABLE_BITCODE'] = 'NO'
end
puts "[ok] Configured build settings for #{ui_test_target.build_configurations.length} configurations"

# 4. Add RunnerUITests.m to the target's compile sources.
main_group = project.main_group
ui_group = main_group.find_subpath(SOURCE_DIR_NAME, true)
ui_group.set_source_tree('SOURCE_ROOT')
ui_group.set_path(SOURCE_DIR_NAME)

# Group has path = SOURCE_DIR_NAME, so file paths are relative to the group
# (NOT to the project root). Using a bare filename here.
m_file_ref = ui_group.new_reference('RunnerUITests.m')
m_file_ref.last_known_file_type = 'sourcecode.c.objc'
ui_test_target.source_build_phase.add_file_reference(m_file_ref)
puts "[ok] Added RunnerUITests.m to compile sources"

plist_ref = ui_group.new_reference('Info.plist')
plist_ref.last_known_file_type = 'text.plist.xml'
puts "[ok] Added Info.plist as a project reference"

# 5. Make Runner depend on RunnerUITests so building Runner builds the tests.
host_target.add_dependency(ui_test_target)
puts "[ok] Added '#{TARGET_NAME}' as dependency of '#{HOST_TARGET_NAME}'"

# 6. Update shared schemes — add a test action that references the UI test
#    target so `xcodebuild test -scheme <flavor>` discovers it.
schemes_dir = File.join(PROJECT_PATH, 'xcshareddata', 'xcschemes')
%w[Runner dev prod].each do |scheme_name|
  scheme_path = File.join(schemes_dir, "#{scheme_name}.xcscheme")
  next unless File.exist?(scheme_path)

  scheme = Xcodeproj::XCScheme.new(scheme_path)
  already_present = scheme.test_action.testables.any? do |testable|
    testable.buildable_references.any? do |br|
      br.target_name == TARGET_NAME
    end
  end

  if already_present
    puts "[skip] Scheme '#{scheme_name}' already references #{TARGET_NAME}"
    next
  end

  testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(ui_test_target)
  scheme.test_action.add_testable(testable)
  scheme.save_as(PROJECT_PATH, scheme_name, true)
  puts "[ok] Added #{TARGET_NAME} test action to scheme '#{scheme_name}'"
end

# 7. Save the project.
project.save
puts "\n[done] Project saved. Next: run `pod install` from ios/."
