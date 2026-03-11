require "monitor"

module Zvec
  # A vector collection backed by the zvec C++ engine. Provides CRUD
  # operations, vector similarity search, and index management.
  #
  # Collections must be explicitly closed via {#close} before they can be
  # reopened from the same path. Use the +closed?+ method to check state.
  #
  # All mutating operations are thread-safe (protected by a Monitor).
  #
  # @example Create, populate, search, and close
  #   schema = Zvec::Schema.new("articles") do
  #     string "title"
  #     vector "embedding", dimension: 4,
  #            index: Zvec::Ext::HnswIndexParams.new(Zvec::COSINE)
  #   end
  #
  #   col = Zvec::Collection.create_and_open("/tmp/articles", schema)
  #   col.add(pk: "1", title: "Hello", embedding: [0.1, 0.2, 0.3, 0.4])
  #   results = col.search([0.1, 0.2, 0.3, 0.4], top_k: 5)
  #   col.close
  #
  # @example Reopen an existing collection
  #   col = Zvec::Collection.open("/tmp/articles")
  #   puts col.doc_count
  #   col.close
  #
  class Collection
    # @return [Zvec::Schema, nil] the schema, if provided at creation time
    attr_reader :schema

    # @param ext_collection [Ext::Collection] the underlying C++ collection
    # @param schema [Zvec::Schema, nil] optional schema for type-aware access
    # @param name [String, nil] optional collection name
    def initialize(ext_collection, schema: nil, name: nil)
      @ext = ext_collection
      @schema = schema
      @name = name
      @monitor = Monitor.new
      @closed = false
    end

    # Create a new collection on disk and open it.
    #
    # @param path [String] directory path for the collection data
    # @param schema [Zvec::Schema] the collection schema
    # @param read_only [Boolean] open in read-only mode
    # @param enable_mmap [Boolean] use memory-mapped I/O (default: true)
    # @return [Zvec::Collection]
    # @raise [ArgumentError] if path is blank or schema is not a Zvec::Schema
    #
    # @example
    #   col = Zvec::Collection.create_and_open("/tmp/my_col", schema)
    def self.create_and_open(path, schema, read_only: false, enable_mmap: true)
      validate_path!(path)
      raise ArgumentError, "schema must be a Zvec::Schema" unless schema.is_a?(Schema)

      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.create_and_open(path, schema.ext_schema, opts)
      new(ext, schema: schema, name: schema.name)
    end

    # Open an existing collection from disk.
    #
    # @param path [String] directory path of an existing collection
    # @param read_only [Boolean] open in read-only mode
    # @param enable_mmap [Boolean] use memory-mapped I/O (default: true)
    # @return [Zvec::Collection]
    # @raise [ArgumentError] if path is blank
    #
    # @example
    #   col = Zvec::Collection.open("/tmp/my_col", read_only: true)
    def self.open(path, read_only: false, enable_mmap: true)
      validate_path!(path)

      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.open(path, opts)
      new(ext)
    end

    # @return [String, nil] the collection name (from schema or explicit)
    def collection_name
      @name || (@schema ? @schema.name : nil)
    end

    # @return [String] the on-disk path of the collection
    def path
      @ext.path
    end

    # @return [Ext::CollectionStats] collection statistics
    # @raise [Zvec::CollectionError] if the collection is closed
    def stats
      ensure_open!
      @ext.stats
    end

    # @return [Integer] the number of documents in the collection
    # @raise [Zvec::CollectionError] if the collection is closed
    def doc_count
      ensure_open!
      @ext.stats.doc_count
    end

    # @return [Boolean] true if the collection has been closed
    def closed?
      @closed
    end

    # Close the collection, releasing the underlying C++ resources.
    # The collection must be closed before it can be reopened from the
    # same path.
    #
    # @return [void]
    # @raise [Zvec::CollectionError] if already closed
    #
    # @example
    #   col.close
    #   col.closed?  #=> true
    def close
      raise CollectionError, "#{error_prefix}Collection is already closed" if @closed

      @monitor.synchronize do
        begin
          @ext.close
        rescue NoMethodError
          # C++ extension may not expose a close method; the GC will handle it.
        end
        @closed = true
      end
    end

    # --- DDL ---

    # Create an index on a field.
    #
    # @param field_name [String, Symbol] the field to index
    # @param index_params [Ext::HnswIndexParams, Ext::FlatIndexParams,
    #   Ext::IVFIndexParams, Ext::InvertIndexParams] index configuration
    # @return [self]
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if field_name is blank
    #
    # @example
    #   col.create_index("embedding",
    #     Ext::HnswIndexParams.new(Zvec::COSINE, m: 32, ef_construction: 400))
    def create_index(field_name, index_params)
      ensure_open!
      raise ArgumentError, "field_name must be a non-empty string" if field_name.nil? || field_name.to_s.strip.empty?

      @monitor.synchronize do
        @ext.create_index(field_name.to_s, index_params)
      end
      self
    end

    # Drop an index on a field.
    #
    # @param field_name [String, Symbol] the field whose index to drop
    # @return [self]
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if field_name is blank
    def drop_index(field_name)
      ensure_open!
      raise ArgumentError, "field_name must be a non-empty string" if field_name.nil? || field_name.to_s.strip.empty?

      @monitor.synchronize do
        @ext.drop_index(field_name.to_s)
      end
      self
    end

    # Optimize the collection (compact segments, rebuild indexes).
    #
    # @return [self]
    # @raise [Zvec::CollectionError] if the collection is closed
    def optimize
      ensure_open!
      @monitor.synchronize { @ext.optimize }
      self
    end

    # Flush pending writes to disk.
    #
    # @return [self]
    # @raise [Zvec::CollectionError] if the collection is closed
    def flush
      ensure_open!
      @monitor.synchronize { @ext.flush }
      self
    end

    # Destroy the collection, removing all data from disk.
    #
    # @return [void]
    # @raise [Zvec::CollectionError] if the collection is closed
    def destroy
      ensure_open!
      @monitor.synchronize do
        @ext.destroy
        @closed = true
      end
    end

    # --- DML ---

    # Insert one or more documents.
    #
    # @param docs [Zvec::Doc, Array<Zvec::Doc>] document(s) to insert
    # @return [Array<Array(Boolean, String)>] write results
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if docs are not Zvec::Doc instances
    # @raise [Zvec::Error] if any write fails
    #
    # @example
    #   doc = Zvec::Doc.new(pk: "1", schema: schema)
    #   doc["title"] = "Hello"
    #   col.insert(doc)
    def insert(docs)
      ensure_open!
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.insert(ext_docs) }
      check_write_results!(results)
    end

    # Upsert (insert or update) one or more documents.
    #
    # @param docs [Zvec::Doc, Array<Zvec::Doc>] document(s) to upsert
    # @return [Array<Array(Boolean, String)>] write results
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [Zvec::Error] if any write fails
    def upsert(docs)
      ensure_open!
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.upsert(ext_docs) }
      check_write_results!(results)
    end

    # Update one or more existing documents.
    #
    # @param docs [Zvec::Doc, Array<Zvec::Doc>] document(s) to update
    # @return [Array<Array(Boolean, String)>] write results
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [Zvec::Error] if any write fails
    def update(docs)
      ensure_open!
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.update(ext_docs) }
      check_write_results!(results)
    end

    # Delete documents by primary key(s).
    #
    # @param pks [Array<String>] one or more primary keys to delete
    # @return [Array<Array(Boolean, String)>] write results
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if no primary keys are provided
    # @raise [Zvec::Error] if any write fails
    #
    # @example
    #   col.delete("doc-1", "doc-2")
    def delete(*pks)
      ensure_open!
      pks = pks.flatten
      raise ArgumentError, "#{error_prefix}No primary keys provided for delete" if pks.empty?
      pks = pks.map(&:to_s)
      results = @monitor.synchronize { @ext.delete_pks(pks) }
      check_write_results!(results)
    end

    # Delete documents matching a filter expression.
    #
    # @param filter [String] the filter expression (see {VectorQuery} for syntax)
    # @return [void]
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if filter is blank
    #
    # @example
    #   col.delete_by_filter("year < 2020")
    def delete_by_filter(filter)
      ensure_open!
      raise ArgumentError, "#{error_prefix}filter must be a non-empty string" if filter.nil? || filter.to_s.strip.empty?
      @monitor.synchronize { @ext.delete_by_filter(filter) }
    end

    # --- DQL ---

    # Execute a vector similarity search with full control over parameters.
    #
    # @param field_name [String, Symbol] the vector field to search
    # @param vector [Array<Numeric>] the query vector
    # @param topk [Integer] maximum number of results (default: 10)
    # @param filter [String, nil] optional filter expression
    # @param include_vector [Boolean] include stored vectors in results
    # @param output_fields [Array<String>, nil] specific fields to return
    # @param query_params [Ext::HnswQueryParams, Ext::IVFQueryParams,
    #   Ext::FlatQueryParams, nil] search tuning params
    # @return [Array<Zvec::Doc>] result documents with +pk+ and +score+ set
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if vector is empty or contains non-numeric elements
    # @raise [Zvec::DimensionError] if vector dimension doesn't match schema
    #
    # @example
    #   results = col.query(
    #     field_name: "embedding",
    #     vector: [0.1, 0.2, 0.3, 0.4],
    #     topk: 5,
    #     filter: "year > 2024"
    #   )
    #   results.each { |doc| puts "#{doc.pk}: #{doc.score}" }
    def query(field_name:, vector:, topk: 10, filter: nil,
              include_vector: false, output_fields: nil, query_params: nil)
      ensure_open!
      validate_query_vector!(vector, field_name)

      vq = VectorQuery.new(
        field_name: field_name,
        vector: vector,
        topk: topk,
        filter: filter,
        include_vector: include_vector,
        output_fields: output_fields,
        query_params: query_params
      )
      raw_results = @monitor.synchronize { @ext.query(vq.ext_query) }
      raw_results.map do |h|
        Doc.new(
          pk: h["pk"],
          fields: h.reject { |k, _| %w[pk score doc_id].include?(k) },
          schema: @schema
        ).tap { |d| d.instance_variable_set(:@score, h["score"]) }
      end
    end

    # Fetch documents by primary key(s).
    #
    # @param pks [Array<String>] one or more primary keys
    # @return [Hash{String => Zvec::Doc}] mapping of pk to document
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if no primary keys provided
    #
    # @example
    #   docs = col.fetch("doc-1", "doc-2")
    #   docs["doc-1"]["title"]  #=> "Hello"
    def fetch(*pks)
      ensure_open!
      pks = pks.flatten
      raise ArgumentError, "#{error_prefix}No primary keys provided for fetch" if pks.empty?
      pks = pks.map(&:to_s)
      raw = @monitor.synchronize { @ext.fetch(pks) }
      raw.transform_values do |h|
        Doc.new(pk: nil, fields: h, schema: @schema)
      end
    end

    # Convenience method to insert a document from keyword arguments.
    #
    # @param pk [String, Integer] the primary key (required)
    # @param fields [Hash] field name/value pairs
    # @return [Array] write results
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [ArgumentError] if pk is nil
    #
    # @example
    #   col.add(pk: "1", title: "Hello", embedding: [0.1, 0.2, 0.3, 0.4])
    def add(pk:, **fields)
      ensure_open!
      raise ArgumentError, "#{error_prefix}pk must not be nil" if pk.nil?
      doc = Doc.new(pk: pk, fields: fields, schema: @schema)
      insert(doc)
    end

    # Convenience method for simple vector similarity search.
    #
    # Auto-detects the vector field from the schema if not specified.
    #
    # @param vector [Array<Numeric>] the query vector
    # @param field [String, Symbol, nil] vector field name (auto-detected if nil)
    # @param top_k [Integer] number of results (default: 10)
    # @param filter [String, nil] optional filter expression
    # @return [Array<Zvec::Doc>] result documents
    # @raise [Zvec::CollectionError] if the collection is closed
    # @raise [Zvec::Error] if no vector fields exist in the schema
    #
    # @example
    #   results = col.search([0.1, 0.2, 0.3, 0.4], top_k: 5)
    #   results.first.pk     #=> "doc-1"
    #   results.first.score  #=> 0.95
    def search(vector, field: nil, top_k: 10, filter: nil)
      ensure_open!
      raise ArgumentError, "#{error_prefix}vector must be a non-empty Array" unless vector.is_a?(Array) && !vector.empty?

      # Auto-detect vector field if not specified
      fname = field&.to_s
      unless fname
        if @schema
          vfield = @schema.ext_schema.vector_fields.first
          raise CollectionError, "#{error_prefix}No vector fields in schema" unless vfield
          fname = vfield.name
        else
          vfields = @ext.schema.vector_fields
          raise CollectionError, "#{error_prefix}No vector fields in schema" if vfields.empty?
          fname = vfields.first.name
        end
      end
      query(field_name: fname, vector: vector, topk: top_k, filter: filter)
    end

    private

    def self.validate_path!(path)
      raise ArgumentError, "path must be a non-empty string" if path.nil? || path.to_s.strip.empty?
    end

    # @raise [Zvec::CollectionError] if the collection is closed
    def ensure_open!
      raise CollectionError, "#{error_prefix}Collection is closed" if @closed
    end

    def error_prefix
      cn = collection_name
      cn ? "[Collection '#{cn}'] " : ""
    end

    def validate_docs!(docs)
      docs.each_with_index do |doc, i|
        unless doc.is_a?(Doc) || doc.is_a?(Ext::Doc)
          raise ArgumentError,
            "#{error_prefix}Expected Zvec::Doc at index #{i}, got #{doc.class}"
        end
      end
    end

    def validate_query_vector!(vector, field_name)
      raise ArgumentError, "#{error_prefix}vector must be a non-empty Array" unless vector.is_a?(Array) && !vector.empty?

      vector.each_with_index do |v, i|
        unless v.is_a?(Numeric)
          raise ArgumentError,
            "#{error_prefix}Query vector for field '#{field_name}' contains non-numeric element at index #{i}: #{v.inspect}"
        end
      end

      # Dimension check against schema
      return unless @schema

      expected_dim = @schema.field_dimension(field_name.to_s)
      return unless expected_dim

      if vector.size != expected_dim
        raise DimensionError,
          "#{error_prefix}Query vector dimension mismatch for field '#{field_name}': " \
          "expected #{expected_dim}, got #{vector.size}"
      end
    end

    def check_write_results!(results)
      results.each do |ok, msg|
        error_msg = msg.nil? || msg.empty? ? "Write operation failed" : msg
        raise CollectionError, "#{error_prefix}#{error_msg}" unless ok
      end
      results
    end
  end
end
