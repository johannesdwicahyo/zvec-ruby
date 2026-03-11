require "minitest/autorun"
require "minitest/pride"
require "fileutils"
require "tmpdir"

# The C++ extension requires zvec to be installed. For pure-Ruby layer tests,
# we stub the Ext module when the native extension is unavailable.
begin
  require "zvec"
  NATIVE_EXT_AVAILABLE = true
rescue LoadError
  NATIVE_EXT_AVAILABLE = false

  # Minimal stubs so pure-Ruby logic can be tested without the compiled extension.
  module Zvec
    class Error < StandardError; end
    class DimensionError < Error; end
    class SchemaError < Error; end
    class QueryError < Error; end
    class CollectionError < Error; end

    module Ext
      # Stub enums as simple modules with constants
      module DataType
        UNDEFINED = :undefined
        BINARY = :binary; STRING = :string; BOOL = :bool
        INT32 = :int32; INT64 = :int64; UINT32 = :uint32; UINT64 = :uint64
        FLOAT = :float; DOUBLE = :double
        VECTOR_FP32 = :vector_fp32; VECTOR_FP64 = :vector_fp64
        VECTOR_FP16 = :vector_fp16; VECTOR_INT8 = :vector_int8
        SPARSE_VECTOR_FP32 = :sparse_vector_fp32; SPARSE_VECTOR_FP16 = :sparse_vector_fp16
        ARRAY_STRING = :array_string; ARRAY_INT32 = :array_int32
        ARRAY_INT64 = :array_int64; ARRAY_FLOAT = :array_float
        ARRAY_DOUBLE = :array_double; ARRAY_BOOL = :array_bool
      end

      module MetricType
        UNDEFINED = :undefined; L2 = :l2; IP = :ip; COSINE = :cosine; MIPSL2 = :mipsl2
      end

      module IndexType
        UNDEFINED = :undefined; HNSW = :hnsw; IVF = :ivf; FLAT = :flat; INVERT = :invert
      end

      module QuantizeType
        UNDEFINED = :undefined; FP16 = :fp16; INT8 = :int8; INT4 = :int4
      end

      class Doc
        attr_accessor :pk, :score
        def initialize; @pk = ""; @score = 0.0; @fields = {}; end
        def field_names; @fields.keys; end
        def has?(f); @fields.key?(f); end
        def has_value?(f); @fields.key?(f) && !@fields[f].nil?; end
        def is_empty; @fields.empty?; end
        alias_method :empty?, :is_empty
        def set_null(f); @fields[f] = nil; end
        def set_string(f, v); @fields[f] = v; end
        def set_bool(f, v); @fields[f] = v; end
        def set_int32(f, v); @fields[f] = v; end
        def set_int64(f, v); @fields[f] = v; end
        def set_uint32(f, v); @fields[f] = v; end
        def set_uint64(f, v); @fields[f] = v; end
        def set_float(f, v); @fields[f] = v; end
        def set_double(f, v); @fields[f] = v; end
        def set_float_vector(f, v); @fields[f] = v; end
        def set_double_vector(f, v); @fields[f] = v; end
        def set_string_array(f, v); @fields[f] = v; end
        def get_string(f); @fields[f].is_a?(String) ? @fields[f] : nil; end
        def get_bool(f); [true, false].include?(@fields[f]) ? @fields[f] : nil; end
        def get_int32(f); @fields[f].is_a?(Integer) ? @fields[f] : nil; end
        def get_int64(f); @fields[f].is_a?(Integer) ? @fields[f] : nil; end
        def get_float(f); @fields[f].is_a?(Float) ? @fields[f] : nil; end
        def get_double(f); @fields[f].is_a?(Float) ? @fields[f] : nil; end
        def get_float_vector(f); @fields[f].is_a?(Array) && (@fields[f].empty? || @fields[f].first.is_a?(Float)) ? @fields[f] : nil; end
        def get_double_vector(f); get_float_vector(f); end
        def get_string_array(f); @fields[f].is_a?(Array) && !@fields[f].empty? && @fields[f].first.is_a?(String) ? @fields[f] : nil; end
        def to_s; "[pk:#{@pk}, score:#{@score}, fields:#{@fields.size}]"; end
      end

      class FieldSchema
        attr_reader :name, :data_type
        attr_accessor :dimension, :nullable
        def initialize(name, data_type); @name = name; @data_type = data_type; @dimension = 0; @nullable = false; end
        def set_index_params(_); end
        def vector_field?; [:vector_fp32, :vector_fp64, :vector_fp16, :vector_int8].include?(@data_type); end
        def to_s; "FieldSchema(#{@name}, #{@data_type})"; end
      end

      class CollectionSchema
        attr_reader :name
        def initialize(name); @name = name; @fields = {}; end
        def add_field(fs); @fields[fs.name] = fs; end
        def has_field?(n); @fields.key?(n); end
        def field_names; @fields.keys; end
        def all_field_names; @fields.keys; end
        def fields; @fields.values; end
        def vector_fields; @fields.values.select(&:vector_field?); end
        def forward_fields; @fields.values.reject(&:vector_field?); end
        def to_s; "CollectionSchema(#{@name})"; end
      end

      class HnswIndexParams
        def initialize(metric, m: 16, ef_construction: 200, quantize_type: nil); end
      end

      class FlatIndexParams
        def initialize(metric, quantize_type: nil); end
      end

      class IVFIndexParams
        def initialize(metric, n_list: 1024, n_iters: 10, use_soar: false, quantize_type: nil); end
      end

      class InvertIndexParams
        def initialize(enable_range_optimization: true, enable_extended_wildcard: false); end
      end

      class HnswQueryParams
        attr_reader :ef
        def initialize(ef: 200); @ef = ef; end
      end

      class IVFQueryParams
        attr_reader :nprobe
        def initialize(nprobe: 10); @nprobe = nprobe; end
      end

      class FlatQueryParams
        def initialize; end
      end

      class CollectionOptions
        attr_accessor :read_only, :enable_mmap, :max_buffer_size
        def initialize; @read_only = false; @enable_mmap = true; @max_buffer_size = 64 * 1024 * 1024; end
        alias_method :read_only?, :read_only
        alias_method :enable_mmap?, :enable_mmap
      end

      class VectorQuery
        attr_accessor :topk, :field_name, :filter, :include_vector
        def initialize; @topk = 10; @field_name = ""; @filter = ""; @include_vector = false; end
        def set_query_vector(arr); @query_vector = arr; end
        def set_output_fields(f); @output_fields = f; end
        def set_query_params(p); @query_params = p; end
        def set_hnsw_query_params(p); @query_params = p; end
        def set_ivf_query_params(p); @query_params = p; end
        def set_flat_query_params(p); @query_params = p; end
        alias_method :include_vector?, :include_vector
      end

      class CollectionStats
        attr_accessor :doc_count
        def initialize; @doc_count = 0; end
        def index_completeness; {}; end
        def to_s; "CollectionStats(doc_count=#{@doc_count})"; end
      end

      class Status
        def initialize(ok = true, msg = ""); @ok = ok; @msg = msg; end
        def ok?; @ok; end
        def message; @msg; end
        def to_s; @ok ? "OK" : @msg; end
      end

      # Stub Collection for pure-Ruby testing of the wrapper layer
      class Collection
        attr_reader :path_value, :schema_value, :docs

        def initialize
          @docs = {}
          @stats = CollectionStats.new
          @path_value = ""
          @closed = false
        end

        def self.create_and_open(path, ext_schema, opts)
          c = new
          c.instance_variable_set(:@path_value, path)
          c.instance_variable_set(:@schema_value, ext_schema)
          c
        end

        def self.open(path, opts)
          c = new
          c.instance_variable_set(:@path_value, path)
          c
        end

        def path; @path_value; end
        def schema; @schema_value; end
        def closed?; @closed; end

        def close
          @closed = true
        end

        def stats
          s = CollectionStats.new
          s.doc_count = @docs.size
          s
        end

        def insert(ext_docs)
          ext_docs.each { |d| @docs[d.pk] = d }
          ext_docs.map { |_| [true, ""] }
        end

        def upsert(ext_docs)
          ext_docs.each { |d| @docs[d.pk] = d }
          ext_docs.map { |_| [true, ""] }
        end

        def update(ext_docs)
          ext_docs.each { |d| @docs[d.pk] = d if @docs.key?(d.pk) }
          ext_docs.map { |_| [true, ""] }
        end

        def delete_pks(pks)
          pks.each { |pk| @docs.delete(pk) }
          pks.map { |_| [true, ""] }
        end

        def delete_by_filter(filter)
          # no-op in stub
        end

        def query(vq)
          @docs.values.first(vq.topk).map do |d|
            h = { "pk" => d.pk, "score" => 0.95 }
            d.field_names.each { |f| h[f] = d.get_string(f) || d.get_int64(f) || d.get_float(f) || d.get_double(f) || d.get_bool(f) || d.get_float_vector(f) || d.get_string_array(f) }
            h
          end
        end

        def fetch(pks)
          result = {}
          pks.each { |pk| result[pk] = @docs[pk] if @docs.key?(pk) }
          result
        end

        def create_index(field_name, index_params); end
        def drop_index(field_name); end
        def optimize; end
        def flush; end
        def destroy; end
      end
    end

    require_relative "../lib/zvec/version"
    require_relative "../lib/zvec/data_types"
    require_relative "../lib/zvec/schema"
    require_relative "../lib/zvec/doc"
    require_relative "../lib/zvec/query"
    require_relative "../lib/zvec/collection"

    include DataTypes
  end
end

# Helper to create a temporary directory that is cleaned up after the test
module TempDirHelper
  def with_temp_dir(prefix = "zvec_test")
    dir = Dir.mktmpdir(prefix)
    yield dir
  ensure
    FileUtils.rm_rf(dir) if dir && Dir.exist?(dir)
  end
end
