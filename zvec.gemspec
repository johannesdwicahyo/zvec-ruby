require_relative "lib/zvec/version"

Gem::Specification.new do |spec|
  spec.name          = "zvec-ruby"
  spec.version       = Zvec::VERSION
  spec.authors       = ["Johannes Dwi Cahyo"]
  spec.summary       = "Ruby bindings for zvec vector database"
  spec.description   = "Ruby gem wrapping the zvec C++ vector database (https://github.com/alibaba/zvec) " \
                        "using Rice. Provides Collection, Doc, Schema, and VectorQuery classes for " \
                        "high-performance vector similarity search, plus integrations for ruby_llm and ActiveRecord."
  spec.homepage      = "https://github.com/johannesdwicahyo/zvec-ruby"
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "ext/**/*.{rb,cpp,h,hpp}",
    "examples/**/*.rb",
    "test/**/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md",
    "Rakefile",
    "zvec.gemspec"
  ]

  spec.metadata = {
    "homepage_uri"    => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri"   => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
  }

  spec.extensions    = ["ext/zvec/extconf.rb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rice", ">= 4.0"

  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
