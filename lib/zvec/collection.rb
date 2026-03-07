module Zvec
  class Collection
    attr_reader :schema

    def initialize(ext_collection, schema: nil)
      @ext = ext_collection
      @schema = schema
    end

    # Create a new collection and open it.
    def self.create_and_open(path, schema, read_only: false, enable_mmap: true)
      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.create_and_open(path, schema.ext_schema, opts)
      new(ext, schema: schema)
    end

    # Open an existing collection.
    def self.open(path, read_only: false, enable_mmap: true)
      opts = Ext::CollectionOptions.new
      opts.read_only = read_only
      opts.enable_mmap = enable_mmap
      ext = Ext::Collection.open(path, opts)
      new(ext)
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
      @ext.create_index(field_name.to_s, index_params)
      self
    end

    def drop_index(field_name)
      @ext.drop_index(field_name.to_s)
      self
    end

    def optimize
      @ext.optimize
      self
    end

    def flush
      @ext.flush
      self
    end

    def destroy
      @ext.destroy
    end

    # --- DML ---

    def insert(docs)
      docs = [docs] unless docs.is_a?(Array)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @ext.insert(ext_docs)
      check_write_results!(results)
    end

    def upsert(docs)
      docs = [docs] unless docs.is_a?(Array)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @ext.upsert(ext_docs)
      check_write_results!(results)
    end

    def update(docs)
      docs = [docs] unless docs.is_a?(Array)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      results = @ext.update(ext_docs)
      check_write_results!(results)
    end

    def delete(*pks)
      pks = pks.flatten.map(&:to_s)
      results = @ext.delete_pks(pks)
      check_write_results!(results)
    end

    def delete_by_filter(filter)
      @ext.delete_by_filter(filter)
    end

    # --- DQL ---

    def query(field_name:, vector:, topk: 10, filter: nil,
              include_vector: false, output_fields: nil, query_params: nil)
      vq = VectorQuery.new(
        field_name: field_name,
        vector: vector,
        topk: topk,
        filter: filter,
        include_vector: include_vector,
        output_fields: output_fields,
        query_params: query_params
      )
      raw_results = @ext.query(vq.ext_query)
      raw_results.map do |h|
        Doc.new(
          pk: h["pk"],
          fields: h.reject { |k, _| %w[pk score doc_id].include?(k) },
          schema: @schema
        ).tap { |d| d.instance_variable_set(:@score, h["score"]) }
      end
    end

    def fetch(*pks)
      pks = pks.flatten.map(&:to_s)
      raw = @ext.fetch(pks)
      raw.transform_values do |h|
        Doc.new(pk: nil, fields: h, schema: @schema)
      end
    end

    # Convenience: insert a hash directly
    def add(pk:, **fields)
      doc = Doc.new(pk: pk, fields: fields, schema: @schema)
      insert(doc)
    end

    private

    def check_write_results!(results)
      results.each do |ok, msg|
        raise Error, (msg.empty? ? "Write operation failed" : msg) unless ok
      end
      results
    end

    public

    # Convenience: search with simpler API
    def search(vector, field: nil, top_k: 10, filter: nil)
      # Auto-detect vector field if not specified
      fname = field&.to_s
      unless fname
        if @schema
          vfield = @schema.ext_schema.vector_fields.first
          raise Error, "No vector fields in schema" unless vfield
          fname = vfield.name
        else
          vfields = @ext.schema.vector_fields
          raise Error, "No vector fields in schema" if vfields.empty?
          fname = vfields.first.name
        end
      end
      query(field_name: fname, vector: vector, topk: top_k, filter: filter)
    end
  end
end
