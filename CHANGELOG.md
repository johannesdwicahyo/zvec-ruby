# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-06

### Added
- Initial release
- Rice-based C++ bindings for zvec vector database
- Ruby DSL for schema definition (`Zvec::Schema`)
- High-level `Zvec::Collection` with `add`, `search`, `query`, `fetch`, `delete`
- `Zvec::Doc` with typed getters/setters and hash-like access
- `Zvec::VectorQuery` for configuring vector similarity searches
- Support for HNSW, Flat, and IVF index types
- Support for L2, IP, and Cosine distance metrics
- `Zvec::RubyLLM::Store` integration for ruby_llm gem
- `Zvec::ActiveRecord::Vectorize` concern for Rails models
- Data type constants for all scalar, vector, sparse vector, and array types
