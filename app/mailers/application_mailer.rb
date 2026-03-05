class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_SENDER"] || ENV["BREVO_SENDER_EMAIL"] || "no-reply@example.com"
  layout "mailer"
end
