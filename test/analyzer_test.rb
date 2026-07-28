require_relative "test_helper"

class AnalyzerTest < Minitest::Test
  def build_query(id)
    NPlusInsight::Query.new(
      sql: %(SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = #{id}),
      duration_ms: 1.25,
      tables: ["comments"]
    )
  end

  def test_reports_a_repeated_query_shape
    detections = NPlusInsight::Analyzer.new(
      request: { request_id: "r1", method: "GET", path: "/posts" },
      queries: [build_query(1), build_query(2), build_query(3)]
    ).call

    assert_equal 1, detections.length
    assert_equal 3, detections.first.query_count
    assert_equal ["comments"], detections.first.models.map { |model| model[:table] }
  end

  def test_ignores_a_single_query
    detections = NPlusInsight::Analyzer.new(
      request: { method: "GET", path: "/posts" },
      queries: [build_query(1)]
    ).call

    assert_empty detections
  end
end
