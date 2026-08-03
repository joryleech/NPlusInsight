require "minitest/autorun"
require_relative "../lib/n_plus_insight/source_location"

class SourceLocationTest < Minitest::Test
  def test_captures_application_method_backtrace
    caller_lines = [
      "/app/serializers/comment_serializer.rb:12:in `author_name'",
      "/app/serializers/post_serializer.rb:8:in `comments'",
      "/gems/active_model_serializers.rb:100:in `serializable_hash'",
      "/app/controllers/posts_controller.rb:5:in `show'"
    ]

    location = NPlusInsight::SourceLocation.from(caller_lines)

    assert_equal "/app/serializers/comment_serializer.rb", location.path
    assert_equal "author_name", location.label
    assert_equal(
      ["author_name", "comments", "show"],
      location.backtrace.map { |frame| frame[:label] }
    )
  end

  def test_limits_the_captured_backtrace
    caller_lines = 35.times.map { |index| "/app/services/service_#{index}.rb:1:in `call'" }

    location = NPlusInsight::SourceLocation.from(caller_lines)

    assert_equal 30, location.backtrace.length
  end
end
