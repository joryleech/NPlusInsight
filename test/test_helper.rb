require "minitest/autorun"
require_relative "../lib/n_plus_insight"

NPlusInsight.configure do |config|
  config.minimum_repetitions = 2
end
