require "rails_helper"

RSpec.describe "Mypage", type: :request do
  before do
    host! "localhost"
  end

  describe "GET /mypage" do
    it "redirects unauthenticated users to sign in" do
      get mypage_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "renders cached user stats" do
      user = create(:user)
      shown_at = Time.zone.local(2026, 4, 23, 9, 45)
      user.update_columns(search_histories_count: 42, last_search_executed_at: shown_at)
      sign_in user

      get mypage_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("検索回数")
      expect(response.body).to match(/検索回数.*?>\s*42\s*</m)
      expect(response.body).to include("2026/04/23 09:45")
    end
  end
end
