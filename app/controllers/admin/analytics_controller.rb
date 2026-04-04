module Admin
  class AnalyticsController < BaseController
    def show
      @dashboard = Analytics::Dashboard.new(admin_user: current_user).call
    end
  end
end
