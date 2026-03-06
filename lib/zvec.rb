require_relative "zvec/version"
require_relative "zvec/zvec_ext"
require_relative "zvec/data_types"
require_relative "zvec/schema"
require_relative "zvec/doc"
require_relative "zvec/query"
require_relative "zvec/collection"

module Zvec
  class Error < StandardError; end

  include DataTypes
end
