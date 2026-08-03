require_relative "test_helper"

class SubscriberTest < Minitest::Test
  def setup
    NPlusInsight::Current.collector = []
  end

  def teardown
    NPlusInsight::Current.collector = nil
  end

  def test_records_query_start_and_duration_for_the_waterfall
    NPlusInsight::Subscriber.record(
      100.25,
      100.253,
      sql: 'SELECT "comments".* FROM "comments" WHERE "comments"."post_id" = 1',
      name: "Comment Load",
      cached: false
    )

    query = NPlusInsight::Current.collector.first

    assert_in_delta 100.25, query.started_at, 0.0001
    assert_in_delta 3.0, query.duration_ms, 0.001
    assert_equal "Comment Load", query.name
  end
end
