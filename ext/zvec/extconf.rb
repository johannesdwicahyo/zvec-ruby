require "mkmf-rice"

# Find zvec installation
zvec_dir = ENV["ZVEC_DIR"]

if zvec_dir
  zvec_include = File.join(zvec_dir, "src", "include")
  zvec_lib = File.join(zvec_dir, "build", "lib")
  zvec_ext_lib = File.join(zvec_dir, "build", "external", "usr", "local", "lib")

  unless File.directory?(zvec_include)
    zvec_include = File.join(zvec_dir, "include")
  end
  unless File.directory?(zvec_lib)
    zvec_lib = File.join(zvec_dir, "lib")
  end

  dir_config("zvec", zvec_include, zvec_lib)
  $INCFLAGS << " -I#{zvec_include}"
  $LDFLAGS << " -L#{zvec_lib}"
  $LDFLAGS << " -L#{zvec_ext_lib}" if File.directory?(zvec_ext_lib)

  # Also add thirdparty include paths for transitive headers
  thirdparty = File.join(zvec_dir, "thirdparty")
  if File.directory?(thirdparty)
    # rocksdb headers
    rocksdb_inc = File.join(thirdparty, "rocksdb", "include")
    $INCFLAGS << " -I#{rocksdb_inc}" if File.directory?(rocksdb_inc)
  end
  # Arrow/external headers from build
  ext_inc = File.join(zvec_dir, "build", "external", "usr", "local", "include")
  $INCFLAGS << " -I#{ext_inc}" if File.directory?(ext_inc)
elsif pkg_config("zvec")
  # pkg-config found it
else
  # Try common install paths
  ["/usr/local", "/opt/homebrew", "/usr"].each do |prefix|
    inc = File.join(prefix, "include")
    lib = File.join(prefix, "lib")
    if File.exist?(File.join(inc, "zvec", "db", "collection.h"))
      $INCFLAGS << " -I#{inc}"
      $LDFLAGS << " -L#{lib}"
      break
    end
  end
end

$CXXFLAGS << " -std=c++17"

have_header("zvec/db/collection.h") or
  abort "Cannot find zvec headers. Set ZVEC_DIR or install zvec system-wide."

# zvec is composed of multiple static libraries that must be linked in order
ZVEC_LIBS = %w[
  zvec_db
  zvec_sqlengine
  zvec_index
  zvec_common
  zvec_core
  zvec_proto
  zvec_ailego
]

THIRDPARTY_LIBS = %w[
  rocksdb
  roaring
  arrow
  arrow_compute
  arrow_acero
  arrow_dataset
  parquet
  arrow_bundled_dependencies
  antlr4-runtime
  protobuf
  glog
  gflags_nothreads
  lz4
]

# Libraries with static initializers (metric/index registration) need force-loading
FORCE_LOAD_LIBS = %w[zvec_core zvec_index]

if RUBY_PLATFORM =~ /darwin/ && defined?(zvec_lib)
  force_flags = FORCE_LOAD_LIBS.map do |l|
    path = File.join(zvec_lib, "lib#{l}.a")
    File.exist?(path) ? "-force_load #{path}" : "-l#{l}"
  end
  normal_libs = (ZVEC_LIBS - FORCE_LOAD_LIBS)
  $libs << " " + force_flags.join(" ")
  $libs << " " + normal_libs.map { |l| "-l#{l}" }.join(" ")
else
  $libs << " -Wl,--whole-archive"
  $libs << " " + FORCE_LOAD_LIBS.map { |l| "-l#{l}" }.join(" ")
  $libs << " -Wl,--no-whole-archive"
  $libs << " " + (ZVEC_LIBS - FORCE_LOAD_LIBS).map { |l| "-l#{l}" }.join(" ")
end
$libs << " " + THIRDPARTY_LIBS.map { |l| "-l#{l}" }.join(" ")
$libs << " -lz -lpthread -ldl -lc++"

create_makefile("zvec/zvec_ext")
