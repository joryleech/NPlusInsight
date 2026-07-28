require_relative "test_helper"

class QueryTest < Minitest::Test
  def test_normalizes_ids_strings_and_in_lists
    query = NPlusInsight::Query.new(
      sql: %(SELECT "comments".* FROM "comments" WHERE "post_id" = 42 AND "state" = 'live' AND "id" IN (1, 2, 3)),
      tables: ["comments"],
      duration_ms: 1
    )

    assert_equal(
      %(SELECT "comments".* FROM "comments" WHERE "post_id" = ? AND "state" = ? AND "id" IN (?)),
      query.normalized_sql
    )
  end
end
