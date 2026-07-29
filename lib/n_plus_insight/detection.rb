module NPlusInsight
  Detection = Struct.new(
    :id, :request_id, :method, :path, :created_at, :query_count, :total_ms,
    :sql, :query_groups, :location, :models, :edges, :tree, :suggestions,
    keyword_init: true
  ) do
    def as_json(*)
      members.to_h { |member| [member, public_send(member)] }
    end
  end
end
