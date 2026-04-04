module Admin
  class AnalyticsController < BaseController
    def show
      @dashboard = Analytics::Dashboard.new.call
    end
  end
end
