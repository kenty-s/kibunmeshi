class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_SENDER"].presence ||
                ENV["BREVO_SENDER_EMAIL"].presence ||
                ENV["SMTP_USERNAME"].presence ||
                "no-reply@example.com"
  layout "mailer"
end
