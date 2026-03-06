require_relative "test_helper"

class TestVectorQuery < Minitest::Test
  def test_initialize_basic
    q = Zvec::VectorQuery.new(
      field_name: "embedding",
      vector: [1.0, 2.0, 3.0]
    )
    assert_kind_of Zvec::VectorQuery, q
    assert_kind_of Zvec::Ext::VectorQuery, q.ext_query
  end

  def test_field_name
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1.0])
    assert_equal "vec", q.ext_query.field_name
  end

  def test_topk_default
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1.0])
    assert_equal 10, q.ext_query.topk
  end

  def test_topk_custom
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1.0], topk: 5)
    assert_equal 5, q.ext_query.topk
  end

  def test_filter
    q = Zvec::VectorQuery.new(
      field_name: "vec", vector: [1.0],
      filter: "year > 2024"
    )
    assert_equal "year > 2024", q.ext_query.filter
  end

  def test_include_vector_default_false
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1.0])
    refute q.ext_query.include_vector?
  end

  def test_include_vector_true
    q = Zvec::VectorQuery.new(
      field_name: "vec", vector: [1.0],
      include_vector: true
    )
    assert q.ext_query.include_vector?
  end

  def test_symbol_field_name
    q = Zvec::VectorQuery.new(field_name: :embedding, vector: [1.0])
    assert_equal "embedding", q.ext_query.field_name
  end

  def test_integer_vector_converted_to_float
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1, 2, 3])
    # Should not raise — integers get .to_f
    assert_kind_of Zvec::VectorQuery, q
  end

  def test_ext_query_accessible
    q = Zvec::VectorQuery.new(field_name: "vec", vector: [1.0])
    refute_nil q.ext_query
  end
end
