require "monitor"

module NPlusInsight
  module Store
    @events = []
    @lock = Monitor.new

    class << self
      def add(event)
        @lock.synchronize do
          @events.unshift(event)
          @events = @events.first(NPlusInsight.configuration.max_events)
        end
      end

      def all = @lock.synchronize { @events.dup }
      def find(id) = @lock.synchronize { @events.find { |event| event.id == id } }
      def clear = @lock.synchronize { @events.clear }
    end
  end
end
