require "rails_helper"

RSpec.describe Analytics::Dashboard do
  describe "#call" do
    it "excludes all admin accounts from trend calculations while keeping reference totals" do
      travel_to Time.zone.parse("2026-04-04 12:00:00") do
        admin_user = create(:user, :admin, name: "管理者")
        other_admin = create(:user, :admin, name: "別管理者")
        other_user = create(:user, name: "一般ユーザー")

        current_week_visit = create_visit_with_page_views(
          started_at: Time.zone.parse("2026-04-02 09:00:00"),
          page_view_times: [
            Time.zone.parse("2026-04-02 09:00:00"),
            Time.zone.parse("2026-04-02 09:05:00")
          ],
          user: admin_user
        )
        other_admin_visit = create_visit_with_page_views(
          started_at: Time.zone.parse("2026-04-03 10:00:00"),
          page_view_times: [
            Time.zone.parse("2026-04-03 10:00:00")
          ],
          user: other_admin
        )
        previous_week_visit = create_visit_with_page_views(
          started_at: Time.zone.parse("2026-03-29 10:00:00"),
          page_view_times: [
            Time.zone.parse("2026-03-29 10:00:00")
          ],
          user: other_user
        )
        previous_month_visit = create_visit_with_page_views(
          started_at: Time.zone.parse("2026-03-01 08:00:00"),
          page_view_times: [
            Time.zone.parse("2026-03-01 08:00:00"),
            Time.zone.parse("2026-03-01 08:10:00"),
            Time.zone.parse("2026-03-01 08:20:00")
          ]
        )

        create_search_event(visit: current_week_visit, time: Time.zone.parse("2026-04-02 09:03:00"), user: admin_user)
        create_search_event(visit: current_week_visit, time: Time.zone.parse("2026-04-03 11:00:00"), user: admin_user)
        create_search_event(visit: other_admin_visit, time: Time.zone.parse("2026-04-03 10:05:00"), user: other_admin)
        create_search_event(visit: previous_week_visit, time: Time.zone.parse("2026-03-29 10:05:00"), user: other_user)
        create_search_event(visit: previous_month_visit, time: Time.zone.parse("2026-03-01 08:05:00"))

        visit_ids = [ current_week_visit.id, other_admin_visit.id, previous_week_visit.id, previous_month_visit.id ]
        page_view_scope = Ahoy::Event.where(name: "page_view", visit_id: visit_ids)
        search_scope = Ahoy::Event.where(name: "search_performed", visit_id: visit_ids)
        visit_scope = Ahoy::Visit.where(id: visit_ids)

        dashboard = described_class.new(
          now: Time.zone.parse("2026-04-04 12:00:00"),
          page_view_scope: page_view_scope,
          visit_scope: visit_scope,
          search_scope: search_scope,
          admin_user: admin_user
        ).call

        expect(dashboard[:totals][:page_views]).to eq(7)
        expect(dashboard[:totals][:visits]).to eq(4)
        expect(dashboard[:totals][:searches]).to eq(5)

        total_card = dashboard[:summary_cards].find { |card| card[:key] == :total }
        expect(total_card[:page_views]).to eq(4)
        expect(total_card[:visits]).to eq(2)
        expect(total_card[:searches]).to eq(2)

        current_week = dashboard[:summary_cards].find { |card| card[:key] == :week }
        expect(current_week[:page_views]).to eq(0)
        expect(current_week[:visits]).to eq(0)
        expect(current_week[:searches]).to eq(0)
        expect(current_week[:page_view_change][:previous]).to eq(1)
        expect(current_week[:page_view_change][:change]).to eq(-1)
        expect(current_week[:search_change][:previous]).to eq(1)
        expect(current_week[:search_change][:change]).to eq(-1)

        current_month = dashboard[:summary_cards].find { |card| card[:key] == :month }
        expect(current_month[:page_views]).to eq(0)
        expect(current_month[:visit_change][:previous]).to eq(2)
        expect(current_month[:searches]).to eq(0)

        today = dashboard[:summary_cards].find { |card| card[:key] == :day }
        expect(today[:page_views]).to eq(0)
        expect(today[:visit_change][:previous]).to eq(0)
        expect(today[:searches]).to eq(0)

        self_segment = dashboard[:audience_breakdown].find { |segment| segment[:key] == :self }
        other_users_segment = dashboard[:audience_breakdown].find { |segment| segment[:key] == :other_users }
        guests_segment = dashboard[:audience_breakdown].find { |segment| segment[:key] == :guests }
        effect_target_segment = dashboard[:audience_breakdown].find { |segment| segment[:key] == :effect_target }

        expect(self_segment[:page_views]).to eq(2)
        expect(self_segment[:searches]).to eq(2)
        expect(other_users_segment[:page_views]).to eq(1)
        expect(guests_segment[:page_views]).to eq(3)
        expect(effect_target_segment[:page_views]).to eq(4)
        expect(effect_target_segment[:visits]).to eq(2)
        expect(effect_target_segment[:searches]).to eq(2)

        self_row = dashboard[:user_rows].find { |row| row[:segment] == :self }
        admin_row = dashboard[:user_rows].find { |row| row[:user_id] == other_admin.id }
        other_row = dashboard[:user_rows].find { |row| row[:user_id] == other_user.id }
        guest_row = dashboard[:user_rows].find { |row| row[:segment] == :guest }

        expect(self_row[:label]).to include("あなた")
        expect(self_row[:page_views]).to eq(2)
        expect(self_row[:effect_target]).to be(false)
        expect(admin_row[:label]).to include("管理者")
        expect(admin_row[:segment]).to eq(:admin)
        expect(admin_row[:effect_target]).to be(false)
        expect(other_row[:page_views]).to eq(1)
        expect(other_row[:effect_target]).to be(true)
        expect(guest_row[:page_views]).to eq(3)
        expect(guest_row[:searches]).to eq(1)

        expect(dashboard[:week_over_week][:page_views][:current]).to eq(0)
        expect(dashboard[:week_over_week][:page_views][:previous]).to eq(1)
        expect(dashboard[:week_over_week][:searches][:current]).to eq(0)

        monthly_chart = dashboard[:charts][:monthly][:data][:datasets]
        total_chart = dashboard[:charts][:total][:data][:datasets]

        expect(dashboard[:charts][:monthly][:data][:labels].length).to eq(6)
        expect(dashboard[:charts][:weekly][:data][:datasets].length).to eq(3)
        expect(dashboard[:charts][:daily][:data][:datasets].last[:data].length).to eq(14)
        expect(monthly_chart[0][:data].last).to eq(0)
        expect(monthly_chart[0][:data][-2]).to eq(4)
        expect(total_chart[0][:data].last).to eq(4)
        expect(total_chart[1][:data].last).to eq(2)
        expect(total_chart[2][:data].last).to eq(2)
      end
    end
  end

  def create_visit_with_page_views(started_at:, page_view_times:, user: nil)
    visit = Ahoy::Visit.create!(
      visit_token: SecureRandom.hex(8),
      visitor_token: SecureRandom.hex(8),
      started_at: started_at,
      user: user
    )

    page_view_times.each do |time|
      Ahoy::Event.create!(
        visit: visit,
        user: user,
        name: "page_view",
        properties: { path: "/" },
        time: time
      )
    end

    visit
  end

  def create_search_event(visit:, time:, user: nil)
    Ahoy::Event.create!(
      visit: visit,
      user: user,
      name: "search_performed",
      properties: { search_mode: "quick" },
      time: time
    )
  end
end
