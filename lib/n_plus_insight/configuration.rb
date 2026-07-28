module NPlusInsight
  class Configuration
    attr_accessor :enabled, :minimum_repetitions, :max_events, :mount_path,
      :ignore_paths, :ignore_sql, :raise_on_detection, :on_page

    def initialize
      @enabled = ENV.fetch("NPLUS_INSIGHT_ENABLED", "false").match?(/\A(?:1|true|yes|on)\z/i)
      @minimum_repetitions = 2
      @max_events = 100
      @mount_path = "/n_plus_insight"
      @ignore_paths = [%r{\A/assets}, %r{\A/packs}, %r{\A/rails/active_storage}]
      @ignore_sql = [/\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i, /schema_migrations/i, /ar_internal_metadata/i]
      @raise_on_detection = false
      @on_page = true
    end
  end
end
