module NPlusInsight
  module Current
    KEY = :__n_plus_insight_collector

    class << self
      def collector = Thread.current[KEY]

      def collector=(value)
        Thread.current[KEY] = value
      end
    end
  end
end
