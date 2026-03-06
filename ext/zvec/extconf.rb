require "mkmf"
require "rice/extconf"

# Find zvec installation
zvec_dir = ENV["ZVEC_DIR"]

if zvec_dir
  zvec_include = File.join(zvec_dir, "src", "include")
  zvec_lib = File.join(zvec_dir, "build", "lib")

  unless File.directory?(zvec_include)
    zvec_include = File.join(zvec_dir, "include")
  end
  unless File.directory?(zvec_lib)
    zvec_lib = File.join(zvec_dir, "lib")
  end

  dir_config("zvec", zvec_include, zvec_lib)
  $INCFLAGS << " -I#{zvec_include}"
  $LDFLAGS << " -L#{zvec_lib}"
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

$libs << " -lzvec"

create_makefile("zvec/zvec_ext")
