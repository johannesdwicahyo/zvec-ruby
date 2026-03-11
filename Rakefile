require "rake/extensiontask"
require "rake/testtask"
require "bundler/gem_tasks"

GEMSPEC = Gem::Specification.load("zvec.gemspec")

CROSS_RUBIES = %w[3.1.0 3.2.0 3.3.0 3.4.0]
CROSS_PLATFORMS = %w[
  x86_64-linux
  aarch64-linux
  x86_64-darwin
  arm64-darwin
]

Rake::ExtensionTask.new("zvec_ext", GEMSPEC) do |ext|
  ext.lib_dir = "lib/zvec"
  ext.ext_dir = "ext/zvec"
  ext.cross_compile  = true
  ext.cross_platform = CROSS_PLATFORMS
  ext.cross_compiling do |spec|
    # Precompiled gems don't need ext/ sources or rice dependency
    spec.files.reject! { |f| f.start_with?("ext/") }
    spec.extensions.clear
    spec.dependencies.reject! { |d| d.name == "rice" }
  end
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
    "test/test_type_detection.rb",
    "test/test_validation.rb",
    "test/test_edge_cases.rb",
    "test/test_active_record.rb",
  ]
  t.warning = true
end

namespace :gem do
  desc "Build native gem for the current platform"
  task :native do
    platform = Gem::Platform.local.to_s
    sh "gem build zvec.gemspec"
    # Repackage with the precompiled .so/.bundle
    puts "\nTo build a platform-specific gem, use:"
    puts "  rake native gem RUBY_CC_VERSION=#{CROSS_RUBIES.join(':')}"
  end

  desc "Build precompiled gems for all platforms using rake-compiler-dock"
  task :precompile do
    require "rake_compiler_dock"

    CROSS_PLATFORMS.each do |plat|
      RakeCompilerDock.sh <<~SCRIPT, platform: plat
        set -e
        # Build zvec inside the container
        git clone --depth 1 https://github.com/alibaba/zvec /tmp/zvec
        cd /tmp/zvec && mkdir build && cd build
        cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
        make -j$(nproc)
        make install
        ldconfig 2>/dev/null || true

        # Build the native gem
        cd /payload
        export ZVEC_DIR=/tmp/zvec
        bundle install
        rake native:#{plat} gem RUBY_CC_VERSION=#{CROSS_RUBIES.join(':')}
      SCRIPT
    end
  end
end

task default: :compile
