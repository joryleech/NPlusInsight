module NPlusInsight
  SourceLocation = Struct.new(:path, :line, :label, :snippet, :backtrace, keyword_init: true) do
    FRAME_PATTERN = /\A(.+?):(\d+)(?::in [`'](.+)[`'])?\z/
    MAX_BACKTRACE_FRAMES = 30

    def self.from(caller_lines)
      root = defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root.to_s.tr("\\", "/") : nil
      frames = caller_lines.filter_map do |entry|
        path = entry.to_s.tr("\\", "/")
        next unless root ? path.start_with?("#{root}/app/", "#{root}/lib/") : !path.include?("/gems/")

        match = FRAME_PATTERN.match(entry.to_s)
        next unless match

        path, line, label = match.captures
        { path: path, line: line.to_i, label: label }
      end.first(MAX_BACKTRACE_FRAMES)
      return if frames.empty?

      frame = frames.first
      new(
        path: frame[:path],
        line: frame[:line],
        label: frame[:label],
        snippet: read_snippet(frame[:path], frame[:line]),
        backtrace: frames
      )
    end

    def self.read_snippet(path, line)
      lines = File.readlines(path)
      first = [line - 3, 0].max
      lines[first, 5].to_a.each_with_index.map do |text, index|
        { line: first + index + 1, text: text.chomp, active: first + index + 1 == line }
      end
    rescue SystemCallError, ArgumentError
      []
    end

    def as_json(*)
      { path: path, line: line, label: label, snippet: snippet, backtrace: backtrace }
    end
  end
end
