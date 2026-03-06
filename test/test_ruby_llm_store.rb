require_relative "test_helper"

# Tests for the RubyLLM::Store integration.
# Requires native extension.
class TestRubyLLMStore < Minitest::Test
  include TempDirHelper

  def setup
    skip "Native extension not available" unless NATIVE_EXT_AVAILABLE
    require "zvec/ruby_llm"
  end

  def test_initialize_creates_collection
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)
      assert_kind_of Zvec::Collection, store.collection
      assert_equal 4, store.dimension
      store.collection.destroy
    end
  end

  def test_initialize_with_metric
    with_temp_dir do |dir|
      [:cosine, :l2, :ip].each_with_index do |metric, i|
        path = File.join(dir, "store_#{i}")
        store = Zvec::RubyLLM::Store.new(path, dimension: 4, metric: metric)
        assert_kind_of Zvec::Collection, store.collection
        store.collection.destroy
      end
    end
  end

  def test_initialize_invalid_metric
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      assert_raises(ArgumentError) do
        Zvec::RubyLLM::Store.new(path, dimension: 4, metric: :invalid)
      end
    end
  end

  def test_add_and_count
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)

      store.add("doc1", embedding: [0.1, 0.2, 0.3, 0.4], content: "Hello")
      assert_equal 1, store.count

      store.add("doc2", embedding: [0.4, 0.3, 0.2, 0.1], content: "World")
      assert_equal 2, store.count

      store.collection.destroy
    end
  end

  def test_add_many
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)

      docs = [
        { id: "a", embedding: [0.1, 0.2, 0.3, 0.4], content: "A" },
        { id: "b", embedding: [0.4, 0.3, 0.2, 0.1], content: "B" },
        { id: "c", embedding: [0.2, 0.4, 0.1, 0.3], content: "C" },
      ]
      store.add_many(docs)
      assert_equal 3, store.count

      store.collection.destroy
    end
  end

  def test_search
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)

      store.add("near", embedding: [1.0, 0.0, 0.0, 0.0], content: "Near")
      store.add("far", embedding: [0.0, 0.0, 0.0, 1.0], content: "Far")

      results = store.search([1.0, 0.0, 0.0, 0.0], top_k: 2)
      assert_kind_of Array, results
      assert_equal 2, results.size

      # Each result is a hash
      first = results.first
      assert_kind_of Hash, first
      assert first.key?(:id)
      assert first.key?(:score)
      assert first.key?(:content)
      assert first.key?(:metadata)

      # Nearest should be "near"
      assert_equal "near", first[:id]

      store.collection.destroy
    end
  end

  def test_search_returns_content
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)

      store.add("d1", embedding: [1.0, 0.0, 0.0, 0.0], content: "Ruby rocks")
      results = store.search([1.0, 0.0, 0.0, 0.0], top_k: 1)
      assert_equal "Ruby rocks", results.first[:content]

      store.collection.destroy
    end
  end

  def test_delete
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)

      store.add("del1", embedding: [0.1, 0.2, 0.3, 0.4])
      store.add("del2", embedding: [0.4, 0.3, 0.2, 0.1])
      assert_equal 2, store.count

      store.delete("del1")
      assert_equal 1, store.count

      store.collection.destroy
    end
  end

  def test_flush
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4)
      store.add("f1", embedding: [0.1, 0.2, 0.3, 0.4])
      store.flush
      # Should not raise
      store.collection.destroy
    end
  end

  def test_custom_vector_field
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4, vector_field: "my_vec")
      store.add("v1", embedding: [0.1, 0.2, 0.3, 0.4])
      assert_equal 1, store.count
      store.collection.destroy
    end
  end

  def test_custom_content_field
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store = Zvec::RubyLLM::Store.new(path, dimension: 4, content_field: "text")
      store.add("c1", embedding: [0.1, 0.2, 0.3, 0.4], content: "Custom")
      results = store.search([0.1, 0.2, 0.3, 0.4], top_k: 1)
      assert_equal "Custom", results.first[:content]
      store.collection.destroy
    end
  end

  def test_reopen_existing_store
    with_temp_dir do |dir|
      path = File.join(dir, "store")
      store1 = Zvec::RubyLLM::Store.new(path, dimension: 4)
      store1.add("r1", embedding: [0.1, 0.2, 0.3, 0.4])
      store1.flush

      # Re-open
      store2 = Zvec::RubyLLM::Store.new(path, dimension: 4)
      assert_equal 1, store2.count

      store2.collection.destroy
    end
  end
end
