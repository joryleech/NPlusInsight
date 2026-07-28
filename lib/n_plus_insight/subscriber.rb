module NPlusInsight
  module Subscriber
    TABLE_PATTERN = /\b(?:FROM|JOIN)\s+["`]?([a-zA-Z_][\w.]*)["`]?/i

    class << self
      def install!
        return if @subscriber
        @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, started, finished, _id, payload|
          record(started, finished, payload)
        end
      end

      def record(started, finished, payload)
        collector = Current.collector
        return unless collector
        sql = payload[:sql].to_s
        config = NPlusInsight.configuration
        return if payload[:cached] || payload[:name].to_s == "SCHEMA"
        return unless sql.lstrip.match?(/\ASELECT\b/i)
        return if config.ignore_sql.any? { |pattern| pattern.match?(sql) }

        collector << Query.new(
          sql: sql,
          name: payload[:name],
          duration_ms: (finished - started) * 1000,
          cached: payload[:cached],
          location: SourceLocation.from(caller),
          tables: sql.scan(TABLE_PATTERN).flatten.map { |table| table.split(".").last.delete('"`') }.uniq
        )
      end
    end
  end
end
