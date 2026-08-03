require "active_record"
require_relative "test_helper"

module AnalyzerFixtures
  class User < ActiveRecord::Base
    self.table_name = "users"
    has_many :posts, class_name: "AnalyzerFixtures::Post"
  end

  class Post < ActiveRecord::Base
    self.table_name = "posts"
    belongs_to :user, class_name: "AnalyzerFixtures::User"
    has_many :comments, class_name: "AnalyzerFixtures::Comment"
    has_many :likes, class_name: "AnalyzerFixtures::Like"
  end

  class Comment < ActiveRecord::Base
    self.table_name = "comments"
    belongs_to :post, class_name: "AnalyzerFixtures::Post"
  end

  class Like < ActiveRecord::Base
    self.table_name = "likes"
    belongs_to :post, class_name: "AnalyzerFixtures::Post"
  end
end

class AnalyzerTest < Minitest::Test
  def location(line = 42)
    NPlusInsight::SourceLocation.new(
      path: "/app/serializers/post_serializer.rb",
      line: line,
      label: "as_json",
      snippet: [
        {
          line: line,
          text: "post.comments.to_a + post.likes.to_a",
          active: true
        }
      ]
    )
  end

  def build_query(table:, foreign_key:, id:, source_location: location, started_at: nil, duration_ms: 1.25)
    NPlusInsight::Query.new(
      sql: %(SELECT "#{table}".* FROM "#{table}" WHERE "#{table}"."#{foreign_key}" = #{id}),
      started_at: started_at,
      duration_ms: duration_ms,
      tables: [table],
      location: source_location
    )
  end

  def analyze(queries)
    NPlusInsight::Analyzer.new(
      request: { request_id: "r1", method: "GET", path: "/posts" },
      queries: queries
    ).call
  end

  def test_reports_a_repeated_query_shape
    detections = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1),
      build_query(table: "comments", foreign_key: "post_id", id: 2),
      build_query(table: "comments", foreign_key: "post_id", id: 3)
    ])

    assert_equal 1, detections.length
    assert_equal 3, detections.first.query_count
    assert_equal 1, detections.first.query_groups.length
    assert_equal(
      ["AnalyzerFixtures::Comment", "AnalyzerFixtures::Post"],
      detections.first.models.map { |model| model[:name] }.sort
    )
  end

  def test_groups_multiple_query_shapes_at_the_same_source_line
    detections = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1),
      build_query(table: "comments", foreign_key: "post_id", id: 2),
      build_query(table: "likes", foreign_key: "post_id", id: 1),
      build_query(table: "likes", foreign_key: "post_id", id: 2),
      build_query(table: "likes", foreign_key: "post_id", id: 3)
    ])

    assert_equal 1, detections.length
    detection = detections.first
    assert_equal 2, detection.query_groups.length
    assert_equal 5, detection.query_count
    assert_equal ["comments", "likes"], detection.query_groups.flat_map { |group| group[:tables] }.sort
    assert_equal ["comments", "likes"], detection.edges.map { |edge| edge[:association].to_s }.sort

    root = detection.tree.fetch(0)
    assert_equal "AnalyzerFixtures::Post", root[:name]
    assert_equal ["AnalyzerFixtures::Comment", "AnalyzerFixtures::Like"], root[:children].map { |child| child[:name] }.sort
    assert_includes detection.suggestions.first[:code], "includes(:comments, :likes)"
  end

  def test_builds_a_nested_tree_and_nested_eager_loading_suggestion
    detections = analyze([
      build_query(table: "posts", foreign_key: "user_id", id: 1),
      build_query(table: "posts", foreign_key: "user_id", id: 2),
      build_query(table: "comments", foreign_key: "post_id", id: 1),
      build_query(table: "comments", foreign_key: "post_id", id: 2),
      build_query(table: "likes", foreign_key: "post_id", id: 1),
      build_query(table: "likes", foreign_key: "post_id", id: 2)
    ])

    assert_equal 1, detections.length
    detection = detections.first
    assert_equal 3, detection.query_groups.length

    user = detection.tree.fetch(0)
    post = user[:children].fetch(0)
    assert_equal "AnalyzerFixtures::User", user[:name]
    assert_equal "AnalyzerFixtures::Post", post[:name]
    assert_equal ["AnalyzerFixtures::Comment", "AnalyzerFixtures::Like"], post[:children].map { |child| child[:name] }.sort
    assert_includes detection.suggestions.first[:code], "includes({ posts: [:comments, :likes] })"
  end

  def test_builds_a_timed_waterfall_across_query_patterns
    detection = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1, started_at: 100.000, duration_ms: 2.0),
      build_query(table: "likes", foreign_key: "post_id", id: 1, started_at: 100.004, duration_ms: 4.0),
      build_query(table: "comments", foreign_key: "post_id", id: 2, started_at: 100.010, duration_ms: 3.0),
      build_query(table: "likes", foreign_key: "post_id", id: 2, started_at: 100.020, duration_ms: 5.0)
    ]).first

    comments = detection.query_groups.find { |group| group[:tables] == ["comments"] }
    likes = detection.query_groups.find { |group| group[:tables] == ["likes"] }

    assert_in_delta 25.0, detection.waterfall_ms, 0.01
    assert_in_delta 14.0, detection.total_ms, 0.01
    assert_equal [0.0, 10.0], comments[:waterfall].map { |query| query[:offset_ms] }
    assert_equal [2.0, 3.0], comments[:waterfall].map { |query| query[:duration_ms] }
    assert_equal [4.0, 20.0], likes[:waterfall].map { |query| query[:offset_ms] }
    assert_equal [4.0, 5.0], likes[:waterfall].map { |query| query[:duration_ms] }
  end

  def test_keeps_repeated_shapes_on_different_lines_separate
    first_location = location(42)
    second_location = location(57)
    detections = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1, source_location: first_location),
      build_query(table: "comments", foreign_key: "post_id", id: 2, source_location: first_location),
      build_query(table: "likes", foreign_key: "post_id", id: 1, source_location: second_location),
      build_query(table: "likes", foreign_key: "post_id", id: 2, source_location: second_location)
    ])

    assert_equal 2, detections.length
    assert_equal [42, 57], detections.map { |detection| detection.location.line }.sort
  end

  def test_does_not_merge_the_same_query_shape_across_source_lines
    first_location = location(42)
    second_location = location(57)
    detections = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1, source_location: first_location),
      build_query(table: "comments", foreign_key: "post_id", id: 2, source_location: first_location),
      build_query(table: "comments", foreign_key: "post_id", id: 3, source_location: second_location),
      build_query(table: "comments", foreign_key: "post_id", id: 4, source_location: second_location)
    ])

    assert_equal 2, detections.length
    assert_equal [42, 57], detections.map { |detection| detection.location.line }.sort
    assert_equal [2, 2], detections.map(&:query_count)
  end

  def test_ignores_a_single_query
    detections = analyze([
      build_query(table: "comments", foreign_key: "post_id", id: 1)
    ])

    assert_empty detections
  end
end
