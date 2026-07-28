module NPlusInsight
  SourceLocation = Struct.new(:path, :line, :label, :snippet, keyword_init: true) do
    FRAME_PATTERN = /\A(.+?):(\d+)(?::in [`'](.+)[`'])?\z/

    def self.from(caller_lines)
      root = defined?(Rails) && Rails.respond_to?(:root) && Rails.root ? Rails.root.to_s.tr("\\", "/") : nil
      frame = caller_lines.find do |entry|
        path = entry.to_s.tr("\\", "/")
        root ? path.start_with?("#{root}/app/", "#{root}/lib/") : !path.include?("/gems/")
      end
      return unless frame

      match = FRAME_PATTERN.match(frame.to_s)
      return unless match

      path, line, label = match.captures
      line = line.to_i
      new(path: path, line: line, label: label, snippet: read_snippet(path, line))
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
      { path: path, line: line, label: label, snippet: snippet }
    end
  end
end
