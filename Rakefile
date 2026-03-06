require "rake/extensiontask"
require "rake/testtask"
require "bundler/gem_tasks"

Rake::ExtensionTask.new("zvec_ext") do |ext|
  ext.lib_dir = "lib/zvec"
  ext.ext_dir = "ext/zvec"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/test_*.rb"
  t.warning = true
end

desc "Run pure Ruby tests (no native extension required)"
Rake::TestTask.new(:test_pure) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList[
    "test/test_version.rb",
    "test/test_data_types.rb",
    "test/test_schema.rb",
    "test/test_doc.rb",
    "test/test_query.rb",
    "test/test_active_record.rb",
  ]
  t.warning = true
end

task default: :compile
