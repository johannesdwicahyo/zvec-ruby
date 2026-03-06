require_relative "test_helper"

# Tests for low-level C++ extension bindings.
# Skipped when native ext is not available.
class TestExtBindings < Minitest::Test
  def setup
    skip "Native extension not available" unless NATIVE_EXT_AVAILABLE
  end

  # --- Enums ---

  def test_data_type_enum
    assert_respond_to Zvec::Ext::DataType::STRING, :to_s
    refute_equal Zvec::Ext::DataType::STRING, Zvec::Ext::DataType::INT32
  end

  def test_index_type_enum
    refute_nil Zvec::Ext::IndexType::HNSW
    refute_nil Zvec::Ext::IndexType::FLAT
    refute_nil Zvec::Ext::IndexType::IVF
    refute_nil Zvec::Ext::IndexType::INVERT
  end

  def test_metric_type_enum
    refute_nil Zvec::Ext::MetricType::L2
    refute_nil Zvec::Ext::MetricType::IP
    refute_nil Zvec::Ext::MetricType::COSINE
  end

  def test_quantize_type_enum
    refute_nil Zvec::Ext::QuantizeType::FP16
    refute_nil Zvec::Ext::QuantizeType::INT8
    refute_nil Zvec::Ext::QuantizeType::INT4
  end

  # --- CollectionOptions ---

  def test_collection_options_defaults
    opts = Zvec::Ext::CollectionOptions.new
    refute opts.read_only?
    assert opts.enable_mmap?
  end

  def test_collection_options_setters
    opts = Zvec::Ext::CollectionOptions.new
    opts.read_only = true
    opts.enable_mmap = false
    opts.max_buffer_size = 1024
    assert opts.read_only?
    refute opts.enable_mmap?
    assert_equal 1024, opts.max_buffer_size
  end

  # --- FieldSchema ---

  def test_field_schema_basic
    fs = Zvec::Ext::FieldSchema.new("title", Zvec::Ext::DataType::STRING)
    assert_equal "title", fs.name
    assert_equal Zvec::Ext::DataType::STRING, fs.data_type
    refute fs.nullable?
    assert_equal 0, fs.dimension
    refute fs.vector_field?
  end

  def test_field_schema_vector
    fs = Zvec::Ext::FieldSchema.new("vec", Zvec::Ext::DataType::VECTOR_FP32)
    fs.dimension = 128
    assert fs.vector_field?
    assert_equal 128, fs.dimension
  end

  def test_field_schema_nullable
    fs = Zvec::Ext::FieldSchema.new("opt", Zvec::Ext::DataType::STRING)
    fs.nullable = true
    assert fs.nullable?
  end

  def test_field_schema_to_s
    fs = Zvec::Ext::FieldSchema.new("x", Zvec::Ext::DataType::INT32)
    assert_kind_of String, fs.to_s
  end

  # --- CollectionSchema ---

  def test_collection_schema_basic
    cs = Zvec::Ext::CollectionSchema.new("test")
    assert_equal "test", cs.name
    assert_equal [], cs.field_names
  end

  def test_collection_schema_add_field
    cs = Zvec::Ext::CollectionSchema.new("test")
    fs = Zvec::Ext::FieldSchema.new("title", Zvec::Ext::DataType::STRING)
    cs.add_field(fs)
    assert cs.has_field?("title")
    assert_includes cs.field_names, "title"
  end

  def test_collection_schema_vector_fields
    cs = Zvec::Ext::CollectionSchema.new("test")
    cs.add_field(Zvec::Ext::FieldSchema.new("title", Zvec::Ext::DataType::STRING))
    vf = Zvec::Ext::FieldSchema.new("vec", Zvec::Ext::DataType::VECTOR_FP32)
    vf.dimension = 4
    cs.add_field(vf)

    vec_fields = cs.vector_fields
    assert_equal 1, vec_fields.size
    assert_equal "vec", vec_fields.first.name
  end

  def test_collection_schema_forward_fields
    cs = Zvec::Ext::CollectionSchema.new("test")
    cs.add_field(Zvec::Ext::FieldSchema.new("title", Zvec::Ext::DataType::STRING))
    vf = Zvec::Ext::FieldSchema.new("vec", Zvec::Ext::DataType::VECTOR_FP32)
    vf.dimension = 4
    cs.add_field(vf)

    fwd = cs.forward_fields
    assert_equal 1, fwd.size
    assert_equal "title", fwd.first.name
  end

  # --- Doc ---

  def test_doc_basic
    d = Zvec::Ext::Doc.new
    assert_equal "", d.pk
    assert_equal 0.0, d.score
    assert d.empty?
  end

  def test_doc_pk
    d = Zvec::Ext::Doc.new
    d.pk = "hello"
    assert_equal "hello", d.pk
  end

  def test_doc_score
    d = Zvec::Ext::Doc.new
    d.score = 0.95
    assert_in_delta 0.95, d.score, 0.001
  end

  def test_doc_string_field
    d = Zvec::Ext::Doc.new
    d.set_string("name", "Alice")
    assert d.has?("name")
    assert d.has_value?("name")
    assert_equal "Alice", d.get_string("name")
  end

  def test_doc_bool_field
    d = Zvec::Ext::Doc.new
    d.set_bool("active", true)
    assert_equal true, d.get_bool("active")
    d.set_bool("active", false)
    assert_equal false, d.get_bool("active")
  end

  def test_doc_int32_field
    d = Zvec::Ext::Doc.new
    d.set_int32("count", 42)
    assert_equal 42, d.get_int32("count")
  end

  def test_doc_int64_field
    d = Zvec::Ext::Doc.new
    d.set_int64("big", 9_999_999_999)
    assert_equal 9_999_999_999, d.get_int64("big")
  end

  def test_doc_float_field
    d = Zvec::Ext::Doc.new
    d.set_float("val", 3.14)
    assert_in_delta 3.14, d.get_float("val"), 0.01
  end

  def test_doc_double_field
    d = Zvec::Ext::Doc.new
    d.set_double("precise", 2.718281828)
    assert_in_delta 2.718281828, d.get_double("precise"), 0.0001
  end

  def test_doc_float_vector_field
    d = Zvec::Ext::Doc.new
    d.set_float_vector("vec", [1.0, 2.0, 3.0])
    result = d.get_float_vector("vec")
    assert_kind_of Array, result
    assert_equal 3, result.size
    assert_in_delta 1.0, result[0], 0.001
  end

  def test_doc_string_array_field
    d = Zvec::Ext::Doc.new
    d.set_string_array("tags", ["a", "b", "c"])
    result = d.get_string_array("tags")
    assert_equal ["a", "b", "c"], result
  end

  def test_doc_null_field
    d = Zvec::Ext::Doc.new
    d.set_null("empty")
    assert d.has?("empty")
    refute d.has_value?("empty")
  end

  def test_doc_field_names
    d = Zvec::Ext::Doc.new
    d.set_string("a", "x")
    d.set_int32("b", 1)
    names = d.field_names
    assert_includes names, "a"
    assert_includes names, "b"
  end

  def test_doc_get_missing_returns_nil
    d = Zvec::Ext::Doc.new
    assert_nil d.get_string("nope")
    assert_nil d.get_int32("nope")
    assert_nil d.get_float("nope")
    assert_nil d.get_float_vector("nope")
  end

  def test_doc_type_mismatch_returns_nil
    d = Zvec::Ext::Doc.new
    d.set_string("x", "hello")
    assert_nil d.get_int32("x")
    assert_nil d.get_float("x")
  end

  def test_doc_to_s
    d = Zvec::Ext::Doc.new
    d.pk = "test"
    assert_kind_of String, d.to_s
    assert_includes d.to_s, "test"
  end

  # --- VectorQuery ---

  def test_vector_query_basic
    q = Zvec::Ext::VectorQuery.new
    q.field_name = "vec"
    q.topk = 5
    assert_equal "vec", q.field_name
    assert_equal 5, q.topk
  end

  def test_vector_query_filter
    q = Zvec::Ext::VectorQuery.new
    q.filter = "x > 1"
    assert_equal "x > 1", q.filter
  end

  def test_vector_query_include_vector
    q = Zvec::Ext::VectorQuery.new
    q.include_vector = true
    assert q.include_vector?
  end

  # --- Index params ---

  def test_hnsw_index_params
    p = Zvec::Ext::HnswIndexParams.new(Zvec::Ext::MetricType::COSINE)
    assert_equal 16, p.m
    assert_equal 200, p.ef_construction
    assert_equal Zvec::Ext::MetricType::COSINE, p.metric_type
  end

  def test_hnsw_index_params_custom
    p = Zvec::Ext::HnswIndexParams.new(Zvec::Ext::MetricType::L2, 32, 400)
    assert_equal 32, p.m
    assert_equal 400, p.ef_construction
    assert_equal Zvec::Ext::MetricType::L2, p.metric_type
  end

  def test_flat_index_params
    p = Zvec::Ext::FlatIndexParams.new(Zvec::Ext::MetricType::IP)
    assert_equal Zvec::Ext::MetricType::IP, p.metric_type
  end

  def test_ivf_index_params
    p = Zvec::Ext::IVFIndexParams.new(Zvec::Ext::MetricType::L2, 512, 20)
    assert_equal 512, p.n_list
    assert_equal 20, p.n_iters
  end

  def test_invert_index_params
    p = Zvec::Ext::InvertIndexParams.new
    assert_kind_of Zvec::Ext::InvertIndexParams, p
  end

  # --- Query params ---

  def test_hnsw_query_params
    p = Zvec::Ext::HnswQueryParams.new(300)
    assert_equal 300, p.ef
  end

  def test_hnsw_query_params_default
    p = Zvec::Ext::HnswQueryParams.new
    assert_equal 200, p.ef
  end

  def test_ivf_query_params
    p = Zvec::Ext::IVFQueryParams.new(20)
    assert_equal 20, p.nprobe
  end

  def test_flat_query_params
    p = Zvec::Ext::FlatQueryParams.new
    assert_kind_of Zvec::Ext::FlatQueryParams, p
  end
end
