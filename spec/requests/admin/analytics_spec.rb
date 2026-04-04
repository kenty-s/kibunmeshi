require "rails_helper"

RSpec.describe "Admin analytics", type: :request do
  before do
    host! "localhost"
  end

  describe "GET /admin" do
    it "redirects unauthenticated users to sign in" do
      get admin_root_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "rejects non-admin users" do
      user = create(:user)
      sign_in user

      get admin_root_path

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("管理者のみアクセスできます")
    end

    it "allows admin users to access the dashboard" do
      admin = create(:user, :admin)
      sign_in admin

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("PV / 訪問数 / 検索数ダッシュボード")
      expect(response.body).to include("誰のPVか")
      expect(response.body).to include("効果検証対象")
    end
  end
end
