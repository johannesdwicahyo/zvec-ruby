# Milestones

## v0.1.1 (2026-03-10)

### Changes
- Add automatic type detection for schema fields in `DataTypes`
- Add dimension validation for vector fields in `Schema` and `Collection`
- Add error context with descriptive messages throughout `Collection`, `Doc`, and `Query`
- Add input validation for `Doc` fields (reject nil, type-check against schema)
- Add thread safety to `Collection` operations with mutex-protected state
- Add `test_type_detection.rb` and `test_validation.rb` test suites
- Expand `test_helper.rb` with comprehensive stubs for no-extension testing

## v0.1.0 (Initial release)
- Initial release
