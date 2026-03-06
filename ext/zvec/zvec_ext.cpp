#include <rice/rice.hpp>
#include <rice/stl.hpp>

#include <zvec/db/collection.h>
#include <zvec/db/config.h>
#include <zvec/db/doc.h>
#include <zvec/db/index_params.h>
#include <zvec/db/options.h>
#include <zvec/db/query_params.h>
#include <zvec/db/schema.h>
#include <zvec/db/stats.h>
#include <zvec/db/status.h>
#include <zvec/db/type.h>

#include <cstring>
#include <memory>
#include <string>
#include <vector>

using namespace Rice;

// ---------- helpers ----------

static void throw_if_error(const zvec::Status &status) {
  if (status.ok()) return;
  switch (status.code()) {
    case zvec::StatusCode::NOT_FOUND:
      throw Exception(rb_eKeyError, "%s", status.message().c_str());
    case zvec::StatusCode::INVALID_ARGUMENT:
      throw Exception(rb_eArgError, "%s", status.message().c_str());
    default:
      throw Exception(rb_eRuntimeError, "%s", status.message().c_str());
  }
}

template <typename T>
static T unwrap(const zvec::Result<T> &result) {
  if (result.has_value()) return result.value();
  throw_if_error(result.error());
  // unreachable
  throw Exception(rb_eRuntimeError, "unexpected error");
}

// Convert Ruby Array of floats to a binary string (fp32 query vector)
static std::string floats_to_query_bytes(Rice::Array rb_arr) {
  size_t n = rb_arr.size();
  std::vector<float> buf(n);
  for (size_t i = 0; i < n; ++i) {
    buf[i] = Rice::detail::From_Ruby<float>().convert(rb_arr[i].value());
  }
  std::string s(reinterpret_cast<const char *>(buf.data()),
                buf.size() * sizeof(float));
  return s;
}

// ---------- Rice module ----------

extern "C" void Init_zvec_ext() {
  Module rb_mZvec = define_module("Zvec");
  Module rb_mExt = rb_mZvec.define_module("Ext");

  // ---- enums ----

  define_enum<zvec::DataType>("DataType", rb_mExt)
      .define_value("UNDEFINED", zvec::DataType::UNDEFINED)
      .define_value("BINARY", zvec::DataType::BINARY)
      .define_value("STRING", zvec::DataType::STRING)
      .define_value("BOOL", zvec::DataType::BOOL)
      .define_value("INT32", zvec::DataType::INT32)
      .define_value("INT64", zvec::DataType::INT64)
      .define_value("UINT32", zvec::DataType::UINT32)
      .define_value("UINT64", zvec::DataType::UINT64)
      .define_value("FLOAT", zvec::DataType::FLOAT)
      .define_value("DOUBLE", zvec::DataType::DOUBLE)
      .define_value("VECTOR_BINARY32", zvec::DataType::VECTOR_BINARY32)
      .define_value("VECTOR_BINARY64", zvec::DataType::VECTOR_BINARY64)
      .define_value("VECTOR_FP16", zvec::DataType::VECTOR_FP16)
      .define_value("VECTOR_FP32", zvec::DataType::VECTOR_FP32)
      .define_value("VECTOR_FP64", zvec::DataType::VECTOR_FP64)
      .define_value("VECTOR_INT4", zvec::DataType::VECTOR_INT4)
      .define_value("VECTOR_INT8", zvec::DataType::VECTOR_INT8)
      .define_value("VECTOR_INT16", zvec::DataType::VECTOR_INT16)
      .define_value("SPARSE_VECTOR_FP16", zvec::DataType::SPARSE_VECTOR_FP16)
      .define_value("SPARSE_VECTOR_FP32", zvec::DataType::SPARSE_VECTOR_FP32)
      .define_value("ARRAY_BINARY", zvec::DataType::ARRAY_BINARY)
      .define_value("ARRAY_STRING", zvec::DataType::ARRAY_STRING)
      .define_value("ARRAY_BOOL", zvec::DataType::ARRAY_BOOL)
      .define_value("ARRAY_INT32", zvec::DataType::ARRAY_INT32)
      .define_value("ARRAY_INT64", zvec::DataType::ARRAY_INT64)
      .define_value("ARRAY_UINT32", zvec::DataType::ARRAY_UINT32)
      .define_value("ARRAY_UINT64", zvec::DataType::ARRAY_UINT64)
      .define_value("ARRAY_FLOAT", zvec::DataType::ARRAY_FLOAT)
      .define_value("ARRAY_DOUBLE", zvec::DataType::ARRAY_DOUBLE);

  define_enum<zvec::IndexType>("IndexType", rb_mExt)
      .define_value("UNDEFINED", zvec::IndexType::UNDEFINED)
      .define_value("HNSW", zvec::IndexType::HNSW)
      .define_value("IVF", zvec::IndexType::IVF)
      .define_value("FLAT", zvec::IndexType::FLAT)
      .define_value("INVERT", zvec::IndexType::INVERT);

  define_enum<zvec::MetricType>("MetricType", rb_mExt)
      .define_value("UNDEFINED", zvec::MetricType::UNDEFINED)
      .define_value("L2", zvec::MetricType::L2)
      .define_value("IP", zvec::MetricType::IP)
      .define_value("COSINE", zvec::MetricType::COSINE)
      .define_value("MIPSL2", zvec::MetricType::MIPSL2);

  define_enum<zvec::QuantizeType>("QuantizeType", rb_mExt)
      .define_value("UNDEFINED", zvec::QuantizeType::UNDEFINED)
      .define_value("FP16", zvec::QuantizeType::FP16)
      .define_value("INT8", zvec::QuantizeType::INT8)
      .define_value("INT4", zvec::QuantizeType::INT4);

  // ---- Status ----

  define_class_under<zvec::Status>(rb_mExt, "Status")
      .define_method("ok?", &zvec::Status::ok)
      .define_method("code",
                     [](const zvec::Status &s) {
                       return static_cast<uint32_t>(s.code());
                     })
      .define_method("message", &zvec::Status::message)
      .define_method("to_s", [](const zvec::Status &s) {
        if (s.ok()) return std::string("OK");
        return s.message();
      });

  // ---- CollectionOptions ----

  define_class_under<zvec::CollectionOptions>(rb_mExt, "CollectionOptions")
      .define_constructor(Constructor<zvec::CollectionOptions>())
      .define_method("read_only?",
                     [](const zvec::CollectionOptions &o) {
                       return o.read_only_;
                     })
      .define_method("read_only=",
                     [](zvec::CollectionOptions &o, bool v) {
                       o.read_only_ = v;
                     })
      .define_method("enable_mmap?",
                     [](const zvec::CollectionOptions &o) {
                       return o.enable_mmap_;
                     })
      .define_method("enable_mmap=",
                     [](zvec::CollectionOptions &o, bool v) {
                       o.enable_mmap_ = v;
                     })
      .define_method(
          "max_buffer_size",
          [](const zvec::CollectionOptions &o) { return o.max_buffer_size_; })
      .define_method("max_buffer_size=",
                     [](zvec::CollectionOptions &o, uint32_t v) {
                       o.max_buffer_size_ = v;
                     });

  // ---- CollectionStats ----

  define_class_under<zvec::CollectionStats>(rb_mExt, "CollectionStats")
      .define_method("doc_count",
                     [](const zvec::CollectionStats &s) {
                       return s.doc_count;
                     })
      .define_method("index_completeness",
                     [](const zvec::CollectionStats &s) {
                       Hash h;
                       for (auto &[k, v] : s.index_completeness) {
                         h[String(k)] = v;
                       }
                       return h;
                     })
      .define_method("to_s", &zvec::CollectionStats::to_string);

  // ---- IndexParams ----

  define_class_under<zvec::IndexParams>(rb_mExt, "IndexParams")
      .define_method(
          "type",
          [](const zvec::IndexParams &p) { return p.type(); })
      .define_method("to_s", &zvec::IndexParams::to_string);

  define_class_under<zvec::HnswIndexParams, zvec::VectorIndexParams>(
      rb_mExt, "HnswIndexParams")
      .define_constructor(
          Constructor<zvec::HnswIndexParams, zvec::MetricType, int, int,
                      zvec::QuantizeType>(),
          Arg("metric_type"), Arg("m") = 16, Arg("ef_construction") = 200,
          Arg("quantize_type") = zvec::QuantizeType::UNDEFINED)
      .define_method("m", &zvec::HnswIndexParams::m)
      .define_method("ef_construction",
                     &zvec::HnswIndexParams::ef_construction)
      .define_method("metric_type", &zvec::HnswIndexParams::metric_type);

  define_class_under<zvec::FlatIndexParams, zvec::VectorIndexParams>(
      rb_mExt, "FlatIndexParams")
      .define_constructor(
          Constructor<zvec::FlatIndexParams, zvec::MetricType,
                      zvec::QuantizeType>(),
          Arg("metric_type"),
          Arg("quantize_type") = zvec::QuantizeType::UNDEFINED)
      .define_method("metric_type", &zvec::FlatIndexParams::metric_type);

  define_class_under<zvec::IVFIndexParams, zvec::VectorIndexParams>(
      rb_mExt, "IVFIndexParams")
      .define_constructor(
          Constructor<zvec::IVFIndexParams, zvec::MetricType, int, int, bool,
                      zvec::QuantizeType>(),
          Arg("metric_type"), Arg("n_list") = 1024, Arg("n_iters") = 10,
          Arg("use_soar") = false,
          Arg("quantize_type") = zvec::QuantizeType::UNDEFINED)
      .define_method("n_list", &zvec::IVFIndexParams::n_list)
      .define_method("n_iters", &zvec::IVFIndexParams::n_iters)
      .define_method("metric_type", &zvec::IVFIndexParams::metric_type);

  define_class_under<zvec::VectorIndexParams, zvec::IndexParams>(
      rb_mExt, "VectorIndexParams")
      .define_method("metric_type", &zvec::VectorIndexParams::metric_type)
      .define_method("quantize_type", &zvec::VectorIndexParams::quantize_type);

  define_class_under<zvec::InvertIndexParams, zvec::IndexParams>(
      rb_mExt, "InvertIndexParams")
      .define_constructor(
          Constructor<zvec::InvertIndexParams, bool, bool>(),
          Arg("enable_range_optimization") = true,
          Arg("enable_extended_wildcard") = false);

  // ---- QueryParams ----

  define_class_under<zvec::QueryParams>(rb_mExt, "QueryParams")
      .define_method("type",
                     [](const zvec::QueryParams &p) { return p.type(); });

  define_class_under<zvec::HnswQueryParams, zvec::QueryParams>(
      rb_mExt, "HnswQueryParams")
      .define_constructor(Constructor<zvec::HnswQueryParams, int>(),
                          Arg("ef") = 200)
      .define_method("ef", &zvec::HnswQueryParams::ef);

  define_class_under<zvec::IVFQueryParams, zvec::QueryParams>(
      rb_mExt, "IVFQueryParams")
      .define_constructor(Constructor<zvec::IVFQueryParams, int>(),
                          Arg("nprobe") = 10)
      .define_method("nprobe", &zvec::IVFQueryParams::nprobe);

  define_class_under<zvec::FlatQueryParams, zvec::QueryParams>(
      rb_mExt, "FlatQueryParams")
      .define_constructor(Constructor<zvec::FlatQueryParams>());

  // ---- FieldSchema ----

  define_class_under<zvec::FieldSchema>(rb_mExt, "FieldSchema")
      .define_constructor(
          Constructor<zvec::FieldSchema, const std::string &, zvec::DataType>(),
          Arg("name"), Arg("data_type"))
      .define_method("name", &zvec::FieldSchema::name)
      .define_method("data_type", &zvec::FieldSchema::data_type)
      .define_method("dimension", &zvec::FieldSchema::dimension)
      .define_method("dimension=", &zvec::FieldSchema::set_dimension)
      .define_method("nullable?", &zvec::FieldSchema::nullable)
      .define_method("nullable=", &zvec::FieldSchema::set_nullable)
      .define_method("vector_field?",
                     [](const zvec::FieldSchema &f) {
                       return f.is_vector_field();
                     })
      .define_method("index_type", &zvec::FieldSchema::index_type)
      .define_method("set_index_params",
                     [](zvec::FieldSchema &f,
                        const zvec::IndexParams::Ptr &params) {
                       f.set_index_params(params);
                     })
      .define_method("to_s", &zvec::FieldSchema::to_string);

  // ---- CollectionSchema ----

  define_class_under<zvec::CollectionSchema>(rb_mExt, "CollectionSchema")
      .define_constructor(Constructor<zvec::CollectionSchema, const std::string &>(),
                          Arg("name"))
      .define_method("name", &zvec::CollectionSchema::name)
      .define_method("add_field",
                     [](zvec::CollectionSchema &s,
                        zvec::FieldSchema::Ptr field) {
                       auto status = s.add_field(field);
                       throw_if_error(status);
                     })
      .define_method("has_field?", &zvec::CollectionSchema::has_field)
      .define_method("fields", &zvec::CollectionSchema::fields)
      .define_method("field_names", &zvec::CollectionSchema::all_field_names)
      .define_method("vector_fields", &zvec::CollectionSchema::vector_fields)
      .define_method("forward_fields",
                     &zvec::CollectionSchema::forward_fields)
      .define_method("to_s", &zvec::CollectionSchema::to_string);

  // ---- CreateIndexOptions, OptimizeOptions ----

  define_class_under<zvec::CreateIndexOptions>(rb_mExt, "CreateIndexOptions")
      .define_constructor(Constructor<zvec::CreateIndexOptions>())
      .define_method(
          "concurrency",
          [](const zvec::CreateIndexOptions &o) { return o.concurrency_; })
      .define_method("concurrency=",
                     [](zvec::CreateIndexOptions &o, int v) {
                       o.concurrency_ = v;
                     });

  define_class_under<zvec::OptimizeOptions>(rb_mExt, "OptimizeOptions")
      .define_constructor(Constructor<zvec::OptimizeOptions>())
      .define_method(
          "concurrency",
          [](const zvec::OptimizeOptions &o) { return o.concurrency_; })
      .define_method("concurrency=", [](zvec::OptimizeOptions &o, int v) {
        o.concurrency_ = v;
      });

  // ---- Doc ----

  define_class_under<zvec::Doc>(rb_mExt, "Doc")
      .define_constructor(Constructor<zvec::Doc>())
      .define_method("pk", &zvec::Doc::pk)
      .define_method("pk=", &zvec::Doc::set_pk)
      .define_method("score", &zvec::Doc::score)
      .define_method("score=", &zvec::Doc::set_score)
      .define_method("field_names", &zvec::Doc::field_names)
      .define_method("has?", &zvec::Doc::has)
      .define_method("has_value?", &zvec::Doc::has_value)
      .define_method("empty?", &zvec::Doc::is_empty)
      .define_method("set_null", &zvec::Doc::set_null)
      .define_method("to_s", &zvec::Doc::to_string)

      // Typed setters
      .define_method("set_string",
                     [](zvec::Doc &d, const std::string &f,
                        const std::string &v) { return d.set(f, v); })
      .define_method("set_bool",
                     [](zvec::Doc &d, const std::string &f, bool v) {
                       return d.set(f, v);
                     })
      .define_method("set_int32",
                     [](zvec::Doc &d, const std::string &f, int32_t v) {
                       return d.set(f, v);
                     })
      .define_method("set_int64",
                     [](zvec::Doc &d, const std::string &f, int64_t v) {
                       return d.set(f, v);
                     })
      .define_method("set_uint32",
                     [](zvec::Doc &d, const std::string &f, uint32_t v) {
                       return d.set(f, v);
                     })
      .define_method("set_uint64",
                     [](zvec::Doc &d, const std::string &f, uint64_t v) {
                       return d.set(f, v);
                     })
      .define_method("set_float",
                     [](zvec::Doc &d, const std::string &f, float v) {
                       return d.set(f, v);
                     })
      .define_method("set_double",
                     [](zvec::Doc &d, const std::string &f, double v) {
                       return d.set(f, v);
                     })
      .define_method("set_float_vector",
                     [](zvec::Doc &d, const std::string &f,
                        std::vector<float> v) { return d.set(f, std::move(v)); })
      .define_method("set_double_vector",
                     [](zvec::Doc &d, const std::string &f,
                        std::vector<double> v) {
                       return d.set(f, std::move(v));
                     })
      .define_method("set_string_array",
                     [](zvec::Doc &d, const std::string &f,
                        std::vector<std::string> v) {
                       return d.set(f, std::move(v));
                     })

      // Typed getters
      .define_method("get_string",
                     [](const zvec::Doc &d, const std::string &f)
                         -> Rice::Object {
                       auto v = d.get<std::string>(f);
                       return v ? Rice::Object(String(v.value())) : Qnil;
                     })
      .define_method("get_bool",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<bool>(f);
                       return v ? Rice::Object(v.value() ? Qtrue : Qfalse)
                                : Qnil;
                     })
      .define_method("get_int32",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<int32_t>(f);
                       return v ? Rice::Object(INT2NUM(v.value())) : Qnil;
                     })
      .define_method("get_int64",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<int64_t>(f);
                       return v ? Rice::Object(LONG2NUM(v.value())) : Qnil;
                     })
      .define_method("get_float",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<float>(f);
                       return v ? Rice::Object(rb_float_new(v.value())) : Qnil;
                     })
      .define_method("get_double",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<double>(f);
                       return v ? Rice::Object(rb_float_new(v.value())) : Qnil;
                     })
      .define_method("get_float_vector",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<std::vector<float>>(f);
                       if (!v) return Qnil;
                       Array arr;
                       for (float x : v.value()) arr.push(rb_float_new(x));
                       return arr;
                     })
      .define_method("get_double_vector",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<std::vector<double>>(f);
                       if (!v) return Qnil;
                       Array arr;
                       for (double x : v.value()) arr.push(rb_float_new(x));
                       return arr;
                     })
      .define_method("get_string_array",
                     [](const zvec::Doc &d,
                        const std::string &f) -> Rice::Object {
                       auto v = d.get<std::vector<std::string>>(f);
                       if (!v) return Qnil;
                       Array arr;
                       for (auto &s : v.value()) arr.push(String(s));
                       return arr;
                     });

  // ---- VectorQuery ----

  define_class_under<zvec::VectorQuery>(rb_mExt, "VectorQuery")
      .define_constructor(Constructor<zvec::VectorQuery>())
      .define_method("topk",
                     [](const zvec::VectorQuery &q) { return q.topk_; })
      .define_method("topk=",
                     [](zvec::VectorQuery &q, int v) { q.topk_ = v; })
      .define_method("field_name",
                     [](const zvec::VectorQuery &q) { return q.field_name_; })
      .define_method("field_name=",
                     [](zvec::VectorQuery &q, const std::string &v) {
                       q.field_name_ = v;
                     })
      .define_method("filter",
                     [](const zvec::VectorQuery &q) { return q.filter_; })
      .define_method("filter=",
                     [](zvec::VectorQuery &q, const std::string &v) {
                       q.filter_ = v;
                     })
      .define_method("include_vector?",
                     [](const zvec::VectorQuery &q) {
                       return q.include_vector_;
                     })
      .define_method("include_vector=",
                     [](zvec::VectorQuery &q, bool v) {
                       q.include_vector_ = v;
                     })
      .define_method("set_query_vector",
                     [](zvec::VectorQuery &q, Rice::Array floats) {
                       q.query_vector_ = floats_to_query_bytes(floats);
                     })
      .define_method("set_output_fields",
                     [](zvec::VectorQuery &q, std::vector<std::string> fields) {
                       q.output_fields_ = std::move(fields);
                     })
      .define_method("set_query_params",
                     [](zvec::VectorQuery &q,
                        zvec::QueryParams::Ptr params) {
                       q.query_params_ = params;
                     });

  // ---- Collection ----

  define_class_under<zvec::Collection>(rb_mExt, "Collection")
      // Factory methods
      .define_singleton_function(
          "create_and_open",
          [](const std::string &path, const zvec::CollectionSchema &schema,
             const zvec::CollectionOptions &options) {
            return unwrap(
                zvec::Collection::CreateAndOpen(path, schema, options));
          })
      .define_singleton_function(
          "open",
          [](const std::string &path,
             const zvec::CollectionOptions &options) {
            return unwrap(zvec::Collection::Open(path, options));
          })

      // Properties
      .define_method("path",
                     [](const zvec::Collection &c) {
                       return unwrap(c.Path());
                     })
      .define_method("schema",
                     [](const zvec::Collection &c) {
                       return unwrap(c.Schema());
                     })
      .define_method("options",
                     [](const zvec::Collection &c) {
                       return unwrap(c.Options());
                     })
      .define_method("stats",
                     [](const zvec::Collection &c) {
                       return unwrap(c.Stats());
                     })

      // DDL
      .define_method("destroy",
                     [](zvec::Collection &c) {
                       throw_if_error(c.Destroy());
                     })
      .define_method("flush",
                     [](zvec::Collection &c) { throw_if_error(c.Flush()); })
      .define_method("create_index",
                     [](zvec::Collection &c, const std::string &col,
                        zvec::IndexParams::Ptr params) {
                       throw_if_error(c.CreateIndex(col, params));
                     })
      .define_method("drop_index",
                     [](zvec::Collection &c, const std::string &col) {
                       throw_if_error(c.DropIndex(col));
                     })
      .define_method("optimize",
                     [](zvec::Collection &c) {
                       throw_if_error(c.Optimize());
                     })

      // DML
      .define_method("insert",
                     [](zvec::Collection &c, std::vector<zvec::Doc> docs) {
                       return unwrap(c.Insert(docs));
                     })
      .define_method("upsert",
                     [](zvec::Collection &c, std::vector<zvec::Doc> docs) {
                       return unwrap(c.Upsert(docs));
                     })
      .define_method("update",
                     [](zvec::Collection &c, std::vector<zvec::Doc> docs) {
                       return unwrap(c.Update(docs));
                     })
      .define_method("delete_pks",
                     [](zvec::Collection &c,
                        std::vector<std::string> pks) {
                       return unwrap(c.Delete(pks));
                     })
      .define_method("delete_by_filter",
                     [](zvec::Collection &c, const std::string &filter) {
                       throw_if_error(c.DeleteByFilter(filter));
                     })

      // DQL
      .define_method("query",
                     [](const zvec::Collection &c,
                        const zvec::VectorQuery &q) {
                       return unwrap(c.Query(q));
                     })
      .define_method("fetch",
                     [](const zvec::Collection &c,
                        std::vector<std::string> pks) {
                       auto result = unwrap(c.Fetch(pks));
                       Hash h;
                       for (auto &[k, v] : result) {
                         h[String(k)] = v;
                       }
                       return h;
                     });
}
