module NPlusInsight
  module Overlay
    class << self
      def render(detections)
        payload = Base64.strict_encode64(JSON.generate(detections.map { |detection| serialize(detection) }))
        mount_path = NPlusInsight.configuration.mount_path.chomp("/")

        <<~HTML
          <div id="n1v-root" data-payload="#{payload}"></div>
          <link rel="stylesheet" href="#{mount_path}/assets/overlay.css">
          <script src="#{mount_path}/assets/overlay.js" defer></script>
        HTML
      end

      private

      def serialize(detection)
        {
          id: detection.id,
          method: detection.method,
          path: detection.path,
          query_count: detection.query_count,
          total_ms: detection.total_ms,
          sql: detection.sql,
          location: detection.location&.as_json,
          models: detection.models,
          edges: detection.edges,
          suggestions: detection.suggestions
        }
      end
    end
  end
end
