#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Adds a `Debug-dev` build configuration to ios/Runner.xcodeproj as an alias
# for the existing `dev-Debug` configuration.
#
# Why: `patrol_cli` (at least through 4.3.1) hardcodes its xcodebuild command
# as `xcodebuild -configuration <ConfigName>-<flavor>` — i.e. it requires the
# config-first naming convention `Debug-dev`. This project uses Flutter's
# older flavor-first convention `dev-Debug`. Rather than rename every config
# (which would touch pbxproj, all 3 schemes, codemagic.yaml, and the
# ios/Flutter/*.xcconfig filenames), this script simply adds a parallel
# `Debug-dev` config that points at the same underlying xcconfig.
#
# The script is idempotent — re-running it is a no-op if `Debug-dev` already
# exists.
#
# Usage:
#   ruby scripts/add_debug_dev_alias_config.rb
#
# After running:
#   1. cd ios && pod install           # regenerates Pods to include Debug-dev
#   2. patrol test --target integration_test/patrol_smoke_test.dart \
#                  --flavor dev \
#                  -d "iPhone 15 Pro Max"

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../ios/Runner.xcodeproj', __dir__)
SOURCE_CONFIG_NAME = 'dev-Debug'
ALIAS_CONFIG_NAME = 'Debug-dev'

abort "Project not found at #{PROJECT_PATH}" unless Dir.exist?(PROJECT_PATH)

project = Xcodeproj::Project.open(PROJECT_PATH)

def clone_configuration(owner, source_name, alias_name, project)
  if owner.build_configurations.any? { |c| c.name == alias_name }
    puts "[skip] '#{alias_name}' already exists on #{owner_label(owner)}"
    return false
  end

  source = owner.build_configurations.find { |c| c.name == source_name }
  unless source
    puts "[warn] '#{source_name}' not found on #{owner_label(owner)} — skipping"
    return false
  end

  alias_config = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  alias_config.name = alias_name
  alias_config.build_settings = source.build_settings.dup
  alias_config.base_configuration_reference = source.base_configuration_reference
  owner.build_configuration_list.build_configurations << alias_config

  puts "[ok] Added '#{alias_name}' to #{owner_label(owner)} (base: #{source.base_configuration_reference&.path || '<none>'})"
  true
end

def owner_label(owner)
  owner.is_a?(Xcodeproj::Project::Object::PBXProject) ? 'PBXProject' : "target '#{owner.name}'"
end

# 1. Project-level configurations
project_changed = false
if project.build_configurations.any? { |c| c.name == ALIAS_CONFIG_NAME }
  puts "[skip] '#{ALIAS_CONFIG_NAME}' already exists at PBXProject level"
else
  project_source = project.build_configurations.find { |c| c.name == SOURCE_CONFIG_NAME }
  if project_source
    project_alias = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    project_alias.name = ALIAS_CONFIG_NAME
    project_alias.build_settings = project_source.build_settings.dup
    project_alias.base_configuration_reference = project_source.base_configuration_reference
    project.build_configuration_list.build_configurations << project_alias
    puts "[ok] Added '#{ALIAS_CONFIG_NAME}' to PBXProject (base: #{project_source.base_configuration_reference&.path || '<none>'})"
    project_changed = true
  else
    abort "[fatal] No project-level '#{SOURCE_CONFIG_NAME}' configuration found"
  end
end

# 2. Per-target configurations
%w[Runner RunnerUITests].each do |target_name|
  target = project.targets.find { |t| t.name == target_name }
  unless target
    puts "[warn] Target '#{target_name}' not found — skipping"
    next
  end
  project_changed |= clone_configuration(target, SOURCE_CONFIG_NAME, ALIAS_CONFIG_NAME, project)
end

if project_changed
  project.save
  puts
  puts "Project saved. Next steps:"
  puts "  cd ios && pod install"
  puts "  patrol test --target integration_test/patrol_smoke_test.dart --flavor dev -d \"iPhone 15 Pro Max\""
else
  puts
  puts "Nothing to do — '#{ALIAS_CONFIG_NAME}' already in place everywhere."
end
