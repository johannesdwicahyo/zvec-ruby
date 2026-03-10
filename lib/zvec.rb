require_relative "zvec/version"

# Try loading precompiled native extension first (platform gem),
# then fall back to the compiled-from-source version.
begin
  ruby_version = RUBY_VERSION[/\d+\.\d+/]
  require "zvec/#{ruby_version}/zvec_ext"
rescue LoadError
  require "zvec/zvec_ext"
end

require_relative "zvec/data_types"
require_relative "zvec/schema"
require_relative "zvec/doc"
require_relative "zvec/query"
require_relative "zvec/collection"

module Zvec
  class Error < StandardError; end
  class DimensionError < Error; end

  include DataTypes
end
