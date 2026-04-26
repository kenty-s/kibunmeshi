class MypagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
    @account_errors = []
    load_dashboard_data
  end

  def update
    if @user.update(mypage_account_params)
      redirect_to mypage_path, notice: "アカウント情報を更新しました。"
    else
      load_dashboard_data
      @account_errors = @user.errors.full_messages
      flash.now[:alert] = "アカウント情報を更新できませんでした。"
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = current_user
  end

  def load_dashboard_data
    @search_count = @user.search_histories_count
    @last_executed_at = @user.last_search_executed_at
  end

  def mypage_account_params
    params.require(:user).permit(:name, :email)
  end
end
