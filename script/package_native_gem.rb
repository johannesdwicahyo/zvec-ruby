#!/usr/bin/env ruby
# Package a precompiled native gem for the current (or specified) platform.
#
# Usage: ruby script/package_native_gem.rb [platform]
#
# This script takes the already-compiled extension (.bundle/.so) and
# repackages the gem as a platform-specific gem that doesn't require
# compilation at install time.

require "fileutils"
require "rubygems/package"

platform = ARGV[0] || Gem::Platform.local.to_s
ruby_version = RUBY_VERSION[/\d+\.\d+/]

# Find the compiled extension
ext_glob = File.join(__dir__, "..", "lib", "zvec", "zvec_ext.{bundle,so,dll}")
ext_files = Dir[ext_glob]
if ext_files.empty?
  abort "No compiled extension found. Run `rake compile` first."
end
ext_file = ext_files.first
ext_basename = File.basename(ext_file)

# Create versioned directory for the extension
versioned_dir = File.join(__dir__, "..", "lib", "zvec", ruby_version)
FileUtils.mkdir_p(versioned_dir)
FileUtils.cp(ext_file, File.join(versioned_dir, ext_basename))

# Build a platform-specific gemspec
spec = Gem::Specification.load(File.join(__dir__, "..", "zvec.gemspec"))
spec.platform = Gem::Platform.new(platform)
spec.extensions.clear
spec.dependencies.reject! { |d| d.name == "rice" }
spec.files.reject! { |f| f.start_with?("ext/") }
spec.files << "lib/zvec/#{ruby_version}/#{ext_basename}"

# Package
pkg_dir = File.join(__dir__, "..", "pkg")
FileUtils.mkdir_p(pkg_dir)

# Build the gem into the pkg directory
Dir.chdir(File.join(__dir__, "..")) do
  gem_file = Gem::Package.build(spec)
  FileUtils.mv(gem_file, pkg_dir) if gem_file && File.exist?(gem_file)
  puts "Built: #{File.join(pkg_dir, File.basename(gem_file))}"
end

# Clean up versioned dir
FileUtils.rm_rf(versioned_dir)
