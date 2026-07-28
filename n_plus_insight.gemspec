require_relative "lib/n_plus_insight/version"

Gem::Specification.new do |spec|
  spec.name = "n_plus_insight"
  spec.version = NPlusInsight::VERSION
  spec.authors = ["NPlusInsight contributors"]
  spec.summary = "Detect, locate, visualize, and fix Rails N+1 queries"
  spec.description = "A Rails engine that detects repeated query shapes per request, pinpoints the application code responsible, visualizes affected Active Record models, and recommends eager-loading fixes."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "docs/images/*", "LICENSE.txt", "README.md", "CHANGELOG.md", "RELEASING.md"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true"
  }

  spec.add_dependency "rails", ">= 7.0", "< 9"
end
