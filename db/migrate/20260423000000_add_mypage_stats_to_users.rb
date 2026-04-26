class AddMypageStatsToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :search_histories_count, :integer, default: 0, null: false
    add_column :users, :last_search_executed_at, :datetime

    execute <<~SQL.squish
      UPDATE users
      SET
        search_histories_count = stats.search_histories_count,
        last_search_executed_at = stats.last_search_executed_at
      FROM (
        SELECT
          user_id,
          COUNT(*) AS search_histories_count,
          MAX(executed_at) AS last_search_executed_at
        FROM search_histories
        GROUP BY user_id
      ) AS stats
      WHERE users.id = stats.user_id
    SQL
  end

  def down
    remove_column :users, :last_search_executed_at
    remove_column :users, :search_histories_count
  end
end
