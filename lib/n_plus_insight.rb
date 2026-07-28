require "active_support"
require "active_support/notifications"
require "active_support/core_ext/string/inflections"
require "base64"
require "json"
require "securerandom"
require "time"

require_relative "n_plus_insight/version"
require_relative "n_plus_insight/configuration"
require_relative "n_plus_insight/current"
require_relative "n_plus_insight/query"
require_relative "n_plus_insight/source_location"
require_relative "n_plus_insight/detection"
require_relative "n_plus_insight/analyzer"
require_relative "n_plus_insight/store"
require_relative "n_plus_insight/overlay"
require_relative "n_plus_insight/subscriber"
require_relative "n_plus_insight/middleware"

module NPlusInsight
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
      Store.clear
    end
  end
end

require_relative "n_plus_insight/engine" if defined?(Rails::Engine)
