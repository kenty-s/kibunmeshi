require "rails_helper"

RSpec.describe Analytics::Dashboard do
  describe "#call" do
    it "aggregates page views, visits, and searches across periods" do
      travel_to Time.zone.parse("2026-04-04 12:00:00") do
        current_week_visit = create_visit_with_page_views(started_at: Time.zone.parse("2026-04-02 09:00:00"), page_view_times: [
          Time.zone.parse("2026-04-02 09:00:00"),
          Time.zone.parse("2026-04-02 09:05:00")
        ])
        previous_week_visit = create_visit_with_page_views(started_at: Time.zone.parse("2026-03-29 10:00:00"), page_view_times: [
          Time.zone.parse("2026-03-29 10:00:00")
        ])
        previous_month_visit = create_visit_with_page_views(started_at: Time.zone.parse("2026-03-01 08:00:00"), page_view_times: [
          Time.zone.parse("2026-03-01 08:00:00"),
          Time.zone.parse("2026-03-01 08:10:00"),
          Time.zone.parse("2026-03-01 08:20:00")
        ])

        create_search_event(visit: current_week_visit, time: Time.zone.parse("2026-04-02 09:03:00"))
        create_search_event(visit: current_week_visit, time: Time.zone.parse("2026-04-03 11:00:00"))
        create_search_event(visit: previous_week_visit, time: Time.zone.parse("2026-03-29 10:05:00"))
        create_search_event(visit: previous_month_visit, time: Time.zone.parse("2026-03-01 08:05:00"))

        visit_ids = [ current_week_visit.id, previous_week_visit.id, previous_month_visit.id ]
        page_view_scope = Ahoy::Event.where(name: "page_view", visit_id: visit_ids)
        search_scope = Ahoy::Event.where(name: "search_performed", visit_id: visit_ids)
        visit_scope = Ahoy::Visit.where(id: visit_ids)

        dashboard = described_class.new(
          now: Time.zone.parse("2026-04-04 12:00:00"),
          page_view_scope: page_view_scope,
          visit_scope: visit_scope,
          search_scope: search_scope
        ).call

        expect(dashboard[:totals][:page_views]).to eq(6)
        expect(dashboard[:totals][:visits]).to eq(3)
        expect(dashboard[:totals][:searches]).to eq(4)

        current_week = dashboard[:summary_cards].find { |card| card[:key] == :week }
        expect(current_week[:page_views]).to eq(2)
        expect(current_week[:visits]).to eq(1)
        expect(current_week[:searches]).to eq(2)
        expect(current_week[:page_view_change][:previous]).to eq(1)
        expect(current_week[:page_view_change][:change]).to eq(1)
        expect(current_week[:search_change][:previous]).to eq(1)
        expect(current_week[:search_change][:change]).to eq(1)

        today = dashboard[:summary_cards].find { |card| card[:key] == :day }
        expect(today[:page_views]).to eq(0)
        expect(today[:visit_change][:previous]).to eq(0)
        expect(today[:searches]).to eq(0)

        expect(dashboard[:charts][:monthly][:data][:labels].length).to eq(6)
        expect(dashboard[:charts][:weekly][:data][:datasets].length).to eq(3)
        expect(dashboard[:charts][:daily][:data][:datasets].last[:data].length).to eq(14)
      end
    end
  end

  def create_visit_with_page_views(started_at:, page_view_times:)
    visit = Ahoy::Visit.create!(
      visit_token: SecureRandom.hex(8),
      visitor_token: SecureRandom.hex(8),
      started_at: started_at
    )

    page_view_times.each do |time|
      Ahoy::Event.create!(
        visit: visit,
        name: "page_view",
        properties: { path: "/" },
        time: time
      )
    end

    visit
  end

  def create_search_event(visit:, time:)
    Ahoy::Event.create!(
      visit: visit,
      name: "search_performed",
      properties: { search_mode: "quick" },
      time: time
    )
  end
end
