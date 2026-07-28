module NPlusInsight
  Query = Struct.new(:sql, :name, :duration_ms, :cached, :location, :tables, keyword_init: true) do
    def normalized_sql
      sql.to_s
        .gsub(/'(?:[^']|'')*'/, "?")
        .gsub(/\b\d+(?:\.\d+)?\b/, "?")
        .gsub(/\bIN\s*\((?:\s*\?,?\s*)+\)/i, "IN (?)")
        .gsub(/\s+/, " ")
        .strip
    end

    def binds_signature
      normalized_sql
    end
  end
end
