class SearchHistory < ApplicationRecord
  belongs_to :user, counter_cache: true, touch: true
  belongs_to :dish, optional: true

  scope :recent, -> { order(executed_at: :desc) }

  after_commit :refresh_user_last_search_executed_at, on: %i[create update destroy]

  private

  def refresh_user_last_search_executed_at
    affected_user_ids = [ user_id ]
    affected_user_ids << previous_changes.dig("user_id", 0)

    affected_user_ids.compact.uniq.each do |affected_user_id|
      User.refresh_last_search_executed_at!(affected_user_id)
    end
  end
end
