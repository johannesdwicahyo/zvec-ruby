# zvec-ruby — Milestones

> **Source of truth:** https://github.com/johannesdwicahyo/zvec-ruby/milestones
> **Last synced:** 2026-04-14

This file mirrors the GitHub milestones for this repo. Edit the milestone or issues on GitHub and re-sync, do not hand-edit.

## v1.0.0 — Production Ready (**open**)

_Stable API guarantee, thread safety, comprehensive docs, ecosystem integration, benchmarks_

- [ ] #20 Thread safety audit and guarantees
- [ ] #21 Stable public API freeze
- [ ] #22 Comprehensive getting-started guide and cookbook
- [ ] #23 Ecosystem integration with rag-ruby, onnx-ruby, tokenizer-ruby
- [ ] #24 CI pipeline for all platforms and Ruby versions
- [ ] #25 Production deployment guide and best practices

## v0.4.0 — Advanced Features (**open**)

_Sparse vectors, binary vectors, hybrid search, collection snapshots, migration tooling_

- [ ] #14 Sparse vector support with examples
- [ ] #15 Binary vector support
- [ ] #16 Hybrid search (vector + scalar filter ranking)
- [ ] #17 Collection snapshots and backup
- [ ] #18 Schema migration tooling
- [ ] #19 Multi-vector search (query multiple vector fields)

## v0.3.0 — Performance & Batch Operations (**open**)

_Batch insert optimization, memory profiling, connection pooling, full ActiveRecord integration tests_

- [ ] #8 Batch insert optimization with streaming
- [ ] #9 Connection pooling for thread-safe concurrent access
- [ ] #10 Memory profiling and usage reporting
- [ ] #11 Full ActiveRecord integration tests with Rails
- [ ] #12 Performance benchmark suite
- [ ] #13 Lazy collection loading

## v0.2.0 — Hardening & Documentation (**closed**)

_Better error handling, edge case coverage, filter syntax docs, quantization docs_

- [x] #1 Document filter expression syntax
- [x] #2 Document quantization types and usage
- [x] #3 Improve error handling and custom exception classes
- [x] #4 Add edge case tests for empty vectors, large dimensions, special chars
- [x] #5 Fix collection reopen without explicit close
- [x] #6 Add YARD documentation to all public methods
- [x] #7 Document binary and sparse vector usage
