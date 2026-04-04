module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    private

    def require_admin!
      return if current_user && current_user.respond_to?(:admin?) && current_user.admin?

      redirect_to root_path, alert: "管理者のみアクセスできます"
    end
  end
end
