# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  rescue StandardError => e
    Rails.logger.error("[Users::PasswordsController#create] #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace

    self.resource = resource_class.new
    flash.now[:alert] = "パスワード再設定メールの送信に失敗しました。SMTP設定を確認してください。"
    render :new, status: :unprocessable_entity
  end
end