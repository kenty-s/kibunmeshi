require "rails_helper"

RSpec.describe "Home", type: :request do
  before do
    host! "localhost"
  end

  describe "GET /" do
    it "renders successfully even when analytics tracking fails" do
      allow_any_instance_of(Ahoy::Tracker)
        .to receive(:track)
        .and_raise(ActiveRecord::ConnectionNotEstablished, "db unavailable")

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("今日は何を食べたいですか？")
    end
  end
end
