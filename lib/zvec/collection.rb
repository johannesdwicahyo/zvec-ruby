require "monitor"

module Zvec
  class Collection
    attr_reader :schema

    def initialize(ext_collection, schema: nil, name: nil)
      @ext = ext_collection
      @schema = schema
      @name = name
      @monitor = Monitor.new
    end

    # Create a new collection and open it.
    def self.create_and_open(path, schema, read_only: false, enable_mmap: true)
      validate_path!(path)
      raise ArgumentError, "schema must be a Zvec::Schema" unless schema.is_a?(Schema)

      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.create_and_open(path, schema.ext_schema, opts)
      new(ext, schema: schema, name: schema.name)
    end

    # Open an existing collection.
    def self.open(path, read_only: false, enable_mmap: true)
      validate_path!(path)

      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.open(path, opts)
      new(ext)
    end

    def collection_name
      @name || (@schema ? @schema.name : nil)
    end

    def path
      @ext.path
    end

    def stats
      @ext.stats
    end

    def doc_count
      @ext.stats.doc_count
    end

    # --- DDL ---

    def create_index(field_name, index_params)
      raise ArgumentError, "field_name must be a non-empty string" if field_name.nil? || field_name.to_s.strip.empty?

      @monitor.synchronize do
        @ext.create_index(field_name.to_s, index_params)
      end
      self
    end

    def drop_index(field_name)
      raise ArgumentError, "field_name must be a non-empty string" if field_name.nil? || field_name.to_s.strip.empty?

      @monitor.synchronize do
        @ext.drop_index(field_name.to_s)
      end
      self
    end

    def optimize
      @monitor.synchronize { @ext.optimize }
      self
    end

    def flush
      @monitor.synchronize { @ext.flush }
      self
    end

    def destroy
      @monitor.synchronize { @ext.destroy }
    end

    # --- DML ---

    def insert(docs)
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.insert(ext_docs) }
      check_write_results!(results)
    end

    def upsert(docs)
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.upsert(ext_docs) }
      check_write_results!(results)
    end

    def update(docs)
      docs = [docs] unless docs.is_a?(Array)
      validate_docs!(docs)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @monitor.synchronize { @ext.update(ext_docs) }
      check_write_results!(results)
    end

    def delete(*pks)
      pks = pks.flatten
      raise ArgumentError, "#{error_prefix}No primary keys provided for delete" if pks.empty?
      pks = pks.map(&:to_s)
      results = @monitor.synchronize { @ext.delete_pks(pks) }
      check_write_results!(results)
    end

    def delete_by_filter(filter)
      raise ArgumentError, "#{error_prefix}filter must be a non-empty string" if filter.nil? || filter.to_s.strip.empty?
      @monitor.synchronize { @ext.delete_by_filter(filter) }
    end

    # --- DQL ---

    def query(field_name:, vector:, topk: 10, filter: nil,
              include_vector: false, output_fields: nil, query_params: nil)
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

    def fetch(*pks)
      pks = pks.flatten
      raise ArgumentError, "#{error_prefix}No primary keys provided for fetch" if pks.empty?
      pks = pks.map(&:to_s)
      raw = @monitor.synchronize { @ext.fetch(pks) }
      raw.transform_values do |h|
        Doc.new(pk: nil, fields: h, schema: @schema)
      end
    end

    # Convenience: insert a hash directly
    def add(pk:, **fields)
      raise ArgumentError, "#{error_prefix}pk must not be nil" if pk.nil?
      doc = Doc.new(pk: pk, fields: fields, schema: @schema)
      insert(doc)
    end

    # Convenience: search with simpler API
    def search(vector, field: nil, top_k: 10, filter: nil)
      raise ArgumentError, "#{error_prefix}vector must be a non-empty Array" unless vector.is_a?(Array) && !vector.empty?

      # Auto-detect vector field if not specified
      fname = field&.to_s
      unless fname
        if @schema
          vfield = @schema.ext_schema.vector_fields.first
          raise Error, "#{error_prefix}No vector fields in schema" unless vfield
          fname = vfield.name
        else
          vfields = @ext.schema.vector_fields
          raise Error, "#{error_prefix}No vector fields in schema" if vfields.empty?
          fname = vfields.first.name
        end
      end
      query(field_name: fname, vector: vector, topk: top_k, filter: filter)
    end

    private

    def self.validate_path!(path)
      raise ArgumentError, "path must be a non-empty string" if path.nil? || path.to_s.strip.empty?
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
        raise Error, "#{error_prefix}#{error_msg}" unless ok
      end
      results
    end
  end
end
