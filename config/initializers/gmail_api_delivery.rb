# frozen_string_literal: true

require Rails.root.join("lib/gmail_api_delivery")

ActionMailer::Base.add_delivery_method(
  :gmail_api,
  GmailApiDelivery,
  client_id: ENV["GMAIL_API_CLIENT_ID"],
  client_secret: ENV["GMAIL_API_CLIENT_SECRET"],
  refresh_token: ENV["GMAIL_API_REFRESH_TOKEN"],
  user_id: ENV.fetch("GMAIL_API_USER_ID", "me"),
  open_timeout: ENV.fetch("GMAIL_API_OPEN_TIMEOUT", "5").to_i,
  read_timeout: ENV.fetch("GMAIL_API_READ_TIMEOUT", "10").to_i
)
