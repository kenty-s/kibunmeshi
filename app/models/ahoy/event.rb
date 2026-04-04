class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, optional: true

  scope :page_views, -> { where(name: "page_view") }
  scope :searches, -> { where(name: "search_performed") }
end
