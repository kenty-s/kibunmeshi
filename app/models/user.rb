class User < ApplicationRecord
  has_many :search_histories, dependent: :destroy
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  def send_devise_notification(notification, *args)
    return super unless notification.to_sym == :reset_password_instructions

    notification_mail = devise_mailer.public_send(notification, self, *args)

    if Rails.env.production?
      notification_mail.deliver_now
    else
      notification_mail.deliver_later
    end
  end

  def self.from_omniauth(auth)
    provider = auth.provider
    uid = auth.uid
    email = auth.info.email

    user = find_by(provider: provider, uid: uid)
    return user if user

    user = find_by(email: email)
    if user
      return user if user.provider.blank? && user.uid.blank? && user.update(provider: provider, uid: uid)
      return nil
    end

    create do |new_user|
      new_user.provider = provider
      new_user.uid = uid
      new_user.email = email
      new_user.name = auth.info.name
      new_user.password = Devise.friendly_token[0, 20]
    end
  end
end
