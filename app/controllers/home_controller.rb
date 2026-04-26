class HomeController < ApplicationController
  before_action :disable_home_cache, only: :index

  def index
    @current_time = Time.current
    @time_of_days = case @current_time.hour
    when 6..10
      "朝"
    when 11..16
      "昼"
    else
      "夜"
    end
  end

  private

  def disable_home_cache
    response.headers["Cache-Control"] = "no-store"
  end
end
