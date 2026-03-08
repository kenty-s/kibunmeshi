class ApplicationMailer < ActionMailer::Base
  default from: ENV["MAILER_SENDER"].presence || "noreply.kibunmeshi@gmail.com"
  layout "mailer"
end
