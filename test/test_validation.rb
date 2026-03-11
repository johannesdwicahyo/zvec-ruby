require_relative "test_helper"

class TestValidation < Minitest::Test
  include TempDirHelper

  def setup
    @schema = Zvec::Schema.new("test_validation") do
      string "title"
      int32 "count"
      float "rating"
      bool "active"
      vector "embedding", dimension: 4
    end
  end

  # --- Schema validation ---

  def test_schema_rejects_nil_name
    assert_raises(Zvec::SchemaError) { Zvec::Schema.new(nil) }
  end

  def test_schema_rejects_empty_name
    assert_raises(Zvec::SchemaError) { Zvec::Schema.new("") }
  end

  def test_schema_rejects_blank_name
    assert_raises(Zvec::SchemaError) { Zvec::Schema.new("   ") }
  end

  def test_schema_field_rejects_empty_name
    schema = Zvec::Schema.new("test")
    assert_raises(Zvec::SchemaError) { schema.field("", Zvec::DataTypes::STRING) }
  end

  def test_schema_vector_rejects_zero_dimension
    assert_raises(ArgumentError) do
      Zvec::Schema.new("test") { vector "v", dimension: 0 }
    end
  end

  def test_schema_vector_rejects_negative_dimension
    assert_raises(ArgumentError) do
      Zvec::Schema.new("test") { vector "v", dimension: -1 }
    end
  end

  def test_schema_vector_rejects_non_integer_dimension
    assert_raises(ArgumentError) do
      Zvec::Schema.new("test") { vector "v", dimension: 3.5 }
    end
  end

  def test_schema_field_dimension_tracking
    schema = Zvec::Schema.new("test") do
      vector "embedding", dimension: 128
    end
    assert_equal 128, schema.field_dimension("embedding")
  end

  def test_schema_field_dimension_nil_for_non_vector
    schema = Zvec::Schema.new("test") do
      string "title"
    end
    assert_nil schema.field_dimension("title")
  end

  def test_schema_vector_fields_with_dimensions
    schema = Zvec::Schema.new("test") do
      string "title"
      vector "embedding", dimension: 128
      vector "small_embedding", dimension: 32
    end
    dims = schema.vector_fields_with_dimensions
    assert_equal 128, dims["embedding"]
    assert_equal 32, dims["small_embedding"]
    refute dims.key?("title")
  end

  # --- Doc field name validation ---

  def test_doc_set_rejects_empty_field_name
    doc = Zvec::Doc.new
    assert_raises(ArgumentError) { doc.set("", "value") }
  end

  def test_doc_set_rejects_blank_field_name
    doc = Zvec::Doc.new
    assert_raises(ArgumentError) { doc.set("   ", "value") }
  end

  # --- Dimension validation in Doc ---

  def test_doc_dimension_mismatch_raises_error
    doc = Zvec::Doc.new(schema: @schema)
    assert_raises(Zvec::DimensionError) do
      doc["embedding"] = [1.0, 2.0, 3.0]  # expects 4
    end
  end

  def test_doc_dimension_mismatch_error_message
    doc = Zvec::Doc.new(schema: @schema)
    err = assert_raises(Zvec::DimensionError) do
      doc["embedding"] = [1.0, 2.0]
    end
    assert_includes err.message, "embedding"
    assert_includes err.message, "4"
    assert_includes err.message, "2"
  end

  def test_doc_correct_dimension_accepted
    doc = Zvec::Doc.new(schema: @schema)
    doc["embedding"] = [1.0, 2.0, 3.0, 4.0]
    result = doc["embedding"]
    assert_equal 4, result.size
  end

  def test_doc_empty_vector_accepted
    doc = Zvec::Doc.new(schema: @schema)
    doc["embedding"] = []
    # Empty vectors should be accepted (no dimension to check)
  end

  # --- VectorQuery validation ---

  def test_query_rejects_nil_field_name
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: nil, vector: [1.0])
    end
  end

  def test_query_rejects_empty_field_name
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "", vector: [1.0])
    end
  end

  def test_query_rejects_empty_vector
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "vec", vector: [])
    end
  end

  def test_query_rejects_non_array_vector
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "vec", vector: "not an array")
    end
  end

  def test_query_rejects_non_numeric_vector_elements
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "vec", vector: [1.0, "bad", 3.0])
    end
  end

  def test_query_rejects_zero_topk
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "vec", vector: [1.0], topk: 0)
    end
  end

  def test_query_rejects_negative_topk
    assert_raises(Zvec::QueryError) do
      Zvec::VectorQuery.new(field_name: "vec", vector: [1.0], topk: -1)
    end
  end

  # --- Collection validation (using stubs) ---

  def test_collection_create_rejects_nil_path
    assert_raises(ArgumentError) do
      Zvec::Collection.create_and_open(nil, @schema)
    end
  end

  def test_collection_create_rejects_empty_path
    assert_raises(ArgumentError) do
      Zvec::Collection.create_and_open("", @schema)
    end
  end

  def test_collection_create_rejects_non_schema
    assert_raises(ArgumentError) do
      Zvec::Collection.create_and_open("/tmp/test", "not a schema")
    end
  end

  def test_collection_open_rejects_nil_path
    assert_raises(ArgumentError) do
      Zvec::Collection.open(nil)
    end
  end

  def test_collection_add_rejects_nil_pk
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(ArgumentError) do
        col.add(pk: nil, title: "test")
      end
    end
  end

  def test_collection_search_rejects_empty_vector
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(ArgumentError) do
        col.search([])
      end
    end
  end

  def test_collection_search_rejects_non_array_vector
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(ArgumentError) do
        col.search("not an array")
      end
    end
  end

  def test_collection_delete_rejects_empty_pks
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(ArgumentError) do
        col.delete
      end
    end
  end

  def test_collection_fetch_rejects_empty_pks
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(ArgumentError) do
        col.fetch
      end
    end
  end

  def test_collection_query_dimension_mismatch
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_raises(Zvec::DimensionError) do
        col.query(field_name: "embedding", vector: [1.0, 2.0], topk: 5)
      end
    end
  end

  def test_collection_query_dimension_mismatch_message
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      err = assert_raises(Zvec::DimensionError) do
        col.query(field_name: "embedding", vector: [1.0, 2.0], topk: 5)
      end
      assert_includes err.message, "embedding"
      assert_includes err.message, "4"
      assert_includes err.message, "2"
      assert_includes err.message, "test_validation"
    end
  end

  def test_collection_query_correct_dimension_accepted
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      col.add(pk: "d1", title: "Test", count: 1, rating: 1.0, active: true,
              embedding: [1.0, 2.0, 3.0, 4.0])
      results = col.query(field_name: "embedding", vector: [1.0, 2.0, 3.0, 4.0], topk: 5)
      assert_kind_of Array, results
    end
  end

  # --- Error context includes collection name ---

  def test_error_prefix_includes_collection_name
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      err = assert_raises(ArgumentError) do
        col.delete  # no pks
      end
      assert_includes err.message, "test_validation"
    end
  end

  # --- DimensionError is subclass of Error ---

  def test_dimension_error_is_zvec_error
    assert Zvec::DimensionError < Zvec::Error
  end

  # --- Collection name is accessible ---

  def test_collection_name_from_schema
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_equal "test_validation", col.collection_name
    end
  end

  # --- Thread safety: collection has a monitor ---

  def test_collection_has_monitor
    with_temp_dir("zvec_val") do |dir|
      col = Zvec::Collection.create_and_open("#{dir}/col", @schema)
      assert_respond_to col.instance_variable_get(:@monitor), :synchronize
    end
  end
end
