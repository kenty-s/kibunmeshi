# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  def create
    self.resource = resource_class.send_reset_password_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      append_delivery_notice!
      respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
    else
      respond_with(resource)
    end
  rescue StandardError => e
    Rails.logger.error("[Users::PasswordsController#create] #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n")) if e.backtrace

    self.resource = resource_class.new
    flash.now[:alert] = "パスワード再設定メールの送信に失敗しました。メール送信設定を確認してください。"
    render :new, status: :unprocessable_entity
  end

  private

  def append_delivery_notice!
    return unless development_letter_opener_delivery?

    message = flash[:notice].presence || I18n.t("devise.passwords.send_instructions")
    flash[:notice] = "#{message} 開発環境では実メールは送信されません。/letter_opener で確認してください。"
  end

  def development_letter_opener_delivery?
    Rails.env.development? && ActionMailer::Base.delivery_method == :letter_opener_web
  end
end
