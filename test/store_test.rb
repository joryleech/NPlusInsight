require_relative "test_helper"

class StoreTest < Minitest::Test
  Event = Struct.new(:id)

  def setup
    @original_limit = NPlusInsight.configuration.max_events
    NPlusInsight::Store.clear
  end

  def teardown
    NPlusInsight.configuration.max_events = @original_limit
    NPlusInsight::Store.clear
  end

  def test_rolls_off_oldest_findings_at_the_configured_limit
    NPlusInsight.configuration.max_events = 2

    NPlusInsight::Store.add(Event.new("oldest"))
    NPlusInsight::Store.add(Event.new("middle"))
    NPlusInsight::Store.add(Event.new("newest"))

    assert_equal ["newest", "middle"], NPlusInsight::Store.all.map(&:id)
    assert_nil NPlusInsight::Store.find("oldest")
  end

  def test_clear_removes_all_stored_findings
    NPlusInsight::Store.add(Event.new("finding"))

    NPlusInsight::Store.clear

    assert_empty NPlusInsight::Store.all
  end
end
