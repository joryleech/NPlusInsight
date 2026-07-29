require_relative "lib/n_plus_insight/version"

Gem::Specification.new do |spec|
  repository_url = "https://github.com/joryleech/NPlusInsight"

  spec.name = "n_plus_insight"
  spec.version = NPlusInsight::VERSION
  spec.authors = ["Jory Leech"]
  spec.email = ["joryleech@gmail.com"]
  spec.summary = "Detect, locate, visualize, and fix Rails N+1 queries"
  spec.description = "A Rails engine that groups N+1 query patterns by source line, visualizes affected Active Record associations as trees in an on-page inspector and dashboard, and recommends eager-loading fixes."
  spec.homepage = repository_url
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"
  spec.files = Dir["lib/**/*", "app/**/*", "config/**/*", "docs/images/*", "LICENSE.txt", "README.md", "CHANGELOG.md", "RELEASING.md"]
  spec.require_paths = ["lib"]
  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "rubygems_mfa_required" => "true",
    "homepage_uri" => repository_url,
    "source_code_uri" => "#{repository_url}/tree/master",
    "documentation_uri" => "#{repository_url}/blob/master/README.md",
    "changelog_uri" => "#{repository_url}/blob/master/CHANGELOG.md",
    "bug_tracker_uri" => "#{repository_url}/issues"
  }

  spec.add_dependency "rails", ">= 7.0", "< 9"
end
