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
  # Base error class for all Zvec errors.
  class Error < StandardError; end

  # Raised when vector dimensions do not match the expected schema dimension.
  class DimensionError < Error; end

  # Raised for schema definition errors (invalid field names, types, etc.).
  class SchemaError < Error; end

  # Raised for query construction or execution errors.
  class QueryError < Error; end

  # Raised for collection lifecycle errors (open/close/reopen issues).
  class CollectionError < Error; end

  include DataTypes
end
