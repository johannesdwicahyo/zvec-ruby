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
      statuses = @ext.insert(ext_docs)
      statuses.each { |s| raise Error, s.message unless s.ok? }
      statuses
    end

    def upsert(docs)
      docs = [docs] unless docs.is_a?(Array)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      statuses = @ext.upsert(ext_docs)
      statuses.each { |s| raise Error, s.message unless s.ok? }
      statuses
    end

    def update(docs)
      docs = [docs] unless docs.is_a?(Array)
      ext_docs = docs.map { |d| d.is_a?(Doc) ? d.ext_doc : d }
      statuses = @ext.update(ext_docs)
      statuses.each { |s| raise Error, s.message unless s.ok? }
      statuses
    end

    def delete(*pks)
      pks = pks.flatten.map(&:to_s)
      statuses = @ext.delete_pks(pks)
      statuses.each { |s| raise Error, s.message unless s.ok? }
      statuses
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
      raw_docs = @ext.query(vq.ext_query)
      raw_docs.map { |d| Doc.from_ext(d, schema: @schema) }
    end

    def fetch(*pks)
      pks = pks.flatten.map(&:to_s)
      raw = @ext.fetch(pks)
      raw.transform_values { |d| Doc.from_ext(d, schema: @schema) }
    end

    # Convenience: insert a hash directly
    def add(pk:, **fields)
      doc = Doc.new(pk: pk, fields: fields, schema: @schema)
      insert(doc)
    end

    # Convenience: search with simpler API
    def search(vector, field: nil, top_k: 10, filter: nil)
      # Auto-detect vector field if not specified
      fname = field&.to_s
      unless fname
        vfields = @ext.schema.vector_fields
        raise Error, "No vector fields in schema" if vfields.empty?
        fname = vfields.first.name
      end
      query(field_name: fname, vector: vector, topk: top_k, filter: filter)
    end
  end
end
