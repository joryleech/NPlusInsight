require_relative "lib/n_plus_insight/version"

Gem::Specification.new do |spec|
  spec.name = "n_plus_insight"
  spec.version = NPlusInsight::VERSION
  spec.authors = ["NPlusInsight contributors"]
  spec.summary = "Detect, locate, visualize, and fix Rails N+1 queries"
  spec.description = "A development-only Rails engine that observes SQL per request, finds repeated query shapes, links them to application code, draws the affected model graph, and suggests eager-loading fixes."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "LICENSE.txt", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0", "< 9"
end
