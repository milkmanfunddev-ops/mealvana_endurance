#!/usr/bin/env ruby
# frozen_string_literal: true
#
# One-shot fix: the initial setup script created the RunnerUITests group with
# path = "RunnerUITests" and then added file refs with path = "RunnerUITests/...",
# resulting in resolved paths like ios/RunnerUITests/RunnerUITests/RunnerUITests.m
# (doubled). This script repoints the file refs to be relative to their group.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../ios/Runner.xcodeproj', __dir__)
GROUP_NAME = 'RunnerUITests'

project = Xcodeproj::Project.open(PROJECT_PATH)
group = project.main_group.find_subpath(GROUP_NAME, false)
abort "Group '#{GROUP_NAME}' not found" unless group

group.files.each do |file_ref|
  old_path = file_ref.path
  next unless old_path&.start_with?("#{GROUP_NAME}/")

  new_path = old_path.sub("#{GROUP_NAME}/", '')
  file_ref.path = new_path
  puts "[ok] #{old_path} -> #{new_path}"
end

project.save
puts '[done] Project saved.'
