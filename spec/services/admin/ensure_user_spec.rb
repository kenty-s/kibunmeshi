require "rails_helper"

RSpec.describe Admin::EnsureUser do
  describe "#call" do
    it "creates an admin user from configuration" do
      result = described_class.new(email: "Admin@example.com", password: "password123", name: "本番管理者").call

      user = User.find_by(email: "admin@example.com")

      expect(result.status).to eq(:created)
      expect(user).to be_present
      expect(user.admin).to be(true)
      expect(user.name).to eq("本番管理者")
      expect(user.valid_password?("password123")).to be(true)
    end

    it "promotes an existing user without rotating the password by default" do
      user = create(:user, email: "member@example.com", name: "既存ユーザー", password: "initialpass", password_confirmation: "initialpass", admin: false)

      result = described_class.new(email: user.email, name: "運用管理者").call

      user.reload

      expect(result.status).to eq(:updated)
      expect(user.admin).to be(true)
      expect(user.name).to eq("運用管理者")
      expect(user.valid_password?("initialpass")).to be(true)
    end

    it "updates the password when explicitly requested" do
      user = create(:user, email: "member@example.com", password: "initialpass", password_confirmation: "initialpass", admin: false)

      result = described_class.new(email: user.email, password: "newpass123", force_password_update: true).call

      user.reload

      expect(result.status).to eq(:updated)
      expect(user.admin).to be(true)
      expect(user.valid_password?("newpass123")).to be(true)
    end

    it "skips when admin bootstrap is not configured" do
      existing_admin_count = User.where(admin: true).count

      result = described_class.new(email: nil, password: nil, name: nil).call

      expect(result.status).to eq(:skipped)
      expect(User.where(admin: true).count).to eq(existing_admin_count)
    end

    it "raises when trying to create an admin without a password" do
      expect {
        described_class.new(email: "admin@example.com", password: nil, name: "管理者").call
      }.to raise_error(Admin::EnsureUser::ConfigurationError, /ADMIN_PASSWORD/)
    end
  end
end
