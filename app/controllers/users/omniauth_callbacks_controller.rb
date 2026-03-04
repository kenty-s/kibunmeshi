
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    email = auth&.info&.email
    @user = User.from_omniauth(auth)

    if @user&.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      redirect_to new_user_password_path(email: email),
                  alert: "このメールアドレスは既に登録済みです。パスワード再設定からログインしてください。"
    end
  end
end
