require "rails_helper"

RSpec.describe SearchHistory, type: :model do
  describe "cached mypage stats" do
    it "keeps the user's cached count and latest executed_at in sync" do
      user = create(:user)
      older_history = create(:search_history, user: user, executed_at: Time.zone.local(2026, 4, 20, 8, 30))

      user.reload
      expect(user.search_histories_count).to eq(1)
      expect(user.last_search_executed_at).to eq(older_history.executed_at)

      latest_history = create(:search_history, user: user, executed_at: Time.zone.local(2026, 4, 22, 21, 15))

      user.reload
      expect(user.search_histories_count).to eq(2)
      expect(user.last_search_executed_at).to eq(latest_history.executed_at)

      latest_history.destroy!

      user.reload
      expect(user.search_histories_count).to eq(1)
      expect(user.last_search_executed_at).to eq(older_history.executed_at)

      older_history.destroy!

      user.reload
      expect(user.search_histories_count).to eq(0)
      expect(user.last_search_executed_at).to be_nil
    end
  end
end
