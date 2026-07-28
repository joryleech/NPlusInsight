module NPlusInsight
  class Middleware
    def initialize(app) = @app = app

    def call(env)
      previous = Current.collector
      config = NPlusInsight.configuration
      return @app.call(env) unless config.enabled
      return @app.call(env) if env["PATH_INFO"].to_s.start_with?(config.mount_path)
      return @app.call(env) if config.ignore_paths.any? { |pattern| pattern.match?(env["PATH_INFO"].to_s) }

      queries = []
      Current.collector = queries
      status, headers, body = @app.call(env)

      if injectable_html?(headers, config)
        chunks = []
        body.each { |chunk| chunks << chunk }
        body.close if body.respond_to?(:close)
        detections = analyze(env, queries, config)
        html = chunks.join
        html = inject(html, Overlay.render(detections))
        headers.delete("Content-Length")
        headers.delete("content-length")
        headers["Content-Length"] = html.bytesize.to_s
        [status, headers, [html]]
      else
        analyze(env, queries, config)
        [status, headers, body]
      end
    ensure
      Current.collector = previous
    end

    private

    def injectable_html?(headers, config)
      config.on_page &&
        header_value(headers, "content-type").include?("text/html") &&
        header_value(headers, "content-encoding").empty?
    end

    def header_value(headers, name)
      pair = headers.find { |key, _value| key.to_s.downcase == name }
      pair ? pair.last.to_s : ""
    end

    def analyze(env, queries, config)
      request = {
        request_id: env["action_dispatch.request_id"],
        method: env["REQUEST_METHOD"],
        path: env["PATH_INFO"]
      }
      detections = Analyzer.new(request: request, queries: queries).call
      detections.each { |detection| Store.add(detection) }
      if config.raise_on_detection && detections.any?
        first = detections.first
        raise "N+1 query detected at #{first.location&.path}:#{first.location&.line}"
      end
      detections
    end

    def inject(html, overlay)
      if html.match?(%r{</body>}i)
        html.sub(%r{</body>}i, "#{overlay}</body>")
      else
        "#{html}#{overlay}"
      end
    end
  end
end
