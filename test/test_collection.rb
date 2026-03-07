require_relative "test_helper"

# These tests require the native extension and a working zvec installation.
# They are skipped when NATIVE_EXT_AVAILABLE is false.
class TestCollection < Minitest::Test
  include TempDirHelper

  def setup
    skip "Native extension not available" unless NATIVE_EXT_AVAILABLE

    @schema = Zvec::Schema.new("test_collection") do
      string "title"
      int32 "year"
      float "rating"
      vector "embedding", dimension: 4,
             index: Zvec::Ext::HnswIndexParams.new(Zvec::COSINE)
    end
  end

  # --- Creation ---

  def test_create_and_open
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      assert_kind_of Zvec::Collection, col
      col.destroy
    end
  end

  def test_path
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      assert_equal path, col.path
      col.destroy
    end
  end

  def test_schema_preserved
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      assert_same @schema, col.schema
      col.destroy
    end
  end

  # --- Open existing ---

  def test_open_existing
    skip "Cannot reopen without explicit close (collection locks on open)"
  end

  # --- Insert ---

  def test_insert_single_doc
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      doc = Zvec::Doc.new(pk: "doc1", schema: @schema)
      doc["title"] = "Test"
      doc["year"] = 2025
      doc["rating"] = 4.5
      doc["embedding"] = [0.1, 0.2, 0.3, 0.4]
      result = col.insert(doc)
      assert_kind_of Array, result
      col.destroy
    end
  end

  def test_insert_multiple_docs
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      docs = 3.times.map do |i|
        d = Zvec::Doc.new(pk: "doc#{i}", schema: @schema)
        d["title"] = "Title #{i}"
        d["year"] = 2020 + i
        d["rating"] = i.to_f
        d["embedding"] = [0.1 * i, 0.2, 0.3, 0.4]
        d
      end
      result = col.insert(docs)
      assert_equal 3, result.size
      col.destroy
    end
  end

  # --- Add convenience ---

  def test_add_hash
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "d1", title: "Hi", year: 2025, rating: 5.0,
              embedding: [0.1, 0.2, 0.3, 0.4])
      assert_equal 1, col.doc_count
      col.destroy
    end
  end

  # --- Doc count ---

  def test_doc_count
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      assert_equal 0, col.doc_count

      3.times do |i|
        col.add(pk: "d#{i}", title: "T", year: 2025, rating: 1.0,
                embedding: [0.1, 0.2, 0.3, 0.4])
      end
      assert_equal 3, col.doc_count
      col.destroy
    end
  end

  # --- Fetch ---

  def test_fetch_existing
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "f1", title: "Fetched", year: 2025, rating: 3.0,
              embedding: [0.1, 0.2, 0.3, 0.4])

      result = col.fetch("f1")
      assert_kind_of Hash, result
      assert result.key?("f1")
      doc = result["f1"]
      assert_kind_of Zvec::Doc, doc
      assert_equal "Fetched", doc["title"]
      col.destroy
    end
  end

  def test_fetch_multiple
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "a", title: "A", year: 2025, rating: 1.0, embedding: [0.1, 0.2, 0.3, 0.4])
      col.add(pk: "b", title: "B", year: 2025, rating: 2.0, embedding: [0.4, 0.3, 0.2, 0.1])

      result = col.fetch("a", "b")
      assert_equal 2, result.size
      col.destroy
    end
  end

  # --- Search ---

  def test_search
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "s1", title: "Near", year: 2025, rating: 5.0,
              embedding: [1.0, 0.0, 0.0, 0.0])
      col.add(pk: "s2", title: "Far", year: 2025, rating: 1.0,
              embedding: [0.0, 0.0, 0.0, 1.0])

      results = col.search([1.0, 0.0, 0.0, 0.0], top_k: 2)
      assert_kind_of Array, results
      assert_equal 2, results.size
      results.each { |r| assert_kind_of Zvec::Doc, r }
      # The nearest doc should be "s1"
      assert_equal "s1", results.first.pk
      col.destroy
    end
  end

  def test_search_with_field
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "x", title: "X", year: 2025, rating: 1.0,
              embedding: [1.0, 0.0, 0.0, 0.0])

      results = col.search([1.0, 0.0, 0.0, 0.0], field: :embedding, top_k: 1)
      assert_equal 1, results.size
      col.destroy
    end
  end

  # --- Query ---

  def test_query_with_filter
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "q1", title: "Old", year: 2020, rating: 1.0, embedding: [1.0, 0.0, 0.0, 0.0])
      col.add(pk: "q2", title: "New", year: 2025, rating: 5.0, embedding: [0.9, 0.1, 0.0, 0.0])

      results = col.query(
        field_name: "embedding",
        vector: [1.0, 0.0, 0.0, 0.0],
        topk: 10,
        filter: "year=2025"
      )
      assert results.all? { |r| r.is_a?(Zvec::Doc) }
      col.destroy
    end
  end

  # --- Upsert ---

  def test_upsert
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      doc = Zvec::Doc.new(pk: "u1", schema: @schema)
      doc["title"] = "Original"
      doc["year"] = 2025
      doc["rating"] = 1.0
      doc["embedding"] = [0.1, 0.2, 0.3, 0.4]
      col.insert(doc)

      doc2 = Zvec::Doc.new(pk: "u1", schema: @schema)
      doc2["title"] = "Updated"
      doc2["year"] = 2026
      doc2["rating"] = 5.0
      doc2["embedding"] = [0.4, 0.3, 0.2, 0.1]
      col.upsert(doc2)

      assert_equal 1, col.doc_count
      col.destroy
    end
  end

  # --- Delete ---

  def test_delete
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "del1", title: "Delete me", year: 2025, rating: 1.0,
              embedding: [0.1, 0.2, 0.3, 0.4])
      assert_equal 1, col.doc_count

      col.delete("del1")
      assert_equal 0, col.doc_count
      col.destroy
    end
  end

  def test_delete_multiple
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      3.times { |i| col.add(pk: "d#{i}", title: "T", year: 2025, rating: 1.0, embedding: [0.1, 0.2, 0.3, 0.4]) }
      assert_equal 3, col.doc_count

      col.delete("d0", "d1")
      assert_equal 1, col.doc_count
      col.destroy
    end
  end

  # --- Flush ---

  def test_flush
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "fl1", title: "Flush", year: 2025, rating: 1.0,
              embedding: [0.1, 0.2, 0.3, 0.4])
      result = col.flush
      assert_same col, result
      col.destroy
    end
  end

  # --- Optimize ---

  def test_optimize
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.add(pk: "o1", title: "Opt", year: 2025, rating: 1.0,
              embedding: [0.1, 0.2, 0.3, 0.4])
      result = col.optimize
      assert_same col, result
      col.destroy
    end
  end

  # --- Stats ---

  def test_stats
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      stats = col.stats
      assert_respond_to stats, :doc_count
      assert_respond_to stats, :index_completeness
      col.destroy
    end
  end

  # --- Destroy ---

  def test_destroy
    with_temp_dir do |dir|
      path = File.join(dir, "col")
      col = Zvec::Collection.create_and_open(path, @schema)
      col.destroy
      # After destroy, the collection directory should be gone
      refute Dir.exist?(path)
    end
  end
end
