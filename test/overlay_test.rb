require_relative "test_helper"

class OverlayTest < Minitest::Test
  def test_embeds_serialized_findings_and_self_hosted_assets
    finding = NPlusInsight::Detection.new(
      id: "finding-1",
      method: "GET",
      path: "/posts",
      query_count: 4,
      total_ms: 3.2,
      sql: "SELECT * FROM comments WHERE post_id = ?",
      query_groups: [
        {
          sql: "SELECT * FROM comments WHERE post_id = ?",
          query_count: 4,
          total_ms: 3.2,
          tables: ["comments"]
        }
      ],
      models: [{ name: "Comment", table: "comments" }],
      edges: [],
      tree: [{ name: "Comment", table: "comments", children: [] }],
      suggestions: []
    )

    markup = NPlusInsight::Overlay.render([finding])

    assert_includes markup, 'id="n1v-root"'
    assert_includes markup, "/n_plus_insight/assets/overlay.css"
    encoded = markup[/data-payload="([^"]+)"/, 1]
    payload = JSON.parse(Base64.strict_decode64(encoded))
    assert_equal 4, payload.first.fetch("query_count")
    assert_equal 1, payload.first.fetch("query_groups").length
    assert_equal "Comment", payload.first.fetch("tree").first.fetch("name")
  end
end
