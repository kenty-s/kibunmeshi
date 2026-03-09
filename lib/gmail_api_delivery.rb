# frozen_string_literal: true

require "base64"
require "cgi"
require "json"
require "net/http"
require "uri"

class GmailApiDelivery
  TOKEN_URI = URI("https://oauth2.googleapis.com/token")
  SEND_URI_TEMPLATE = "https://gmail.googleapis.com/gmail/v1/users/%{user_id}/messages/send"

  class DeliveryError < StandardError; end

  def initialize(options = {})
    @client_id = options[:client_id]
    @client_secret = options[:client_secret]
    @refresh_token = options[:refresh_token]
    @user_id = options[:user_id].presence || "me"
    @open_timeout = (options[:open_timeout] || 5).to_i
    @read_timeout = (options[:read_timeout] || 10).to_i
  end

  def deliver!(mail)
    validate_config!
    mail.ready_to_send!

    access_token = fetch_access_token
    response = send_message(access_token, mail)
    return response if success_response?(response)

    raise DeliveryError, "Gmail API send failed (#{response.code}): #{response.body}"
  end

  private

  def validate_config!
    missing = []
    missing << "client_id" if @client_id.blank?
    missing << "client_secret" if @client_secret.blank?
    missing << "refresh_token" if @refresh_token.blank?
    return if missing.empty?

    raise DeliveryError, "Missing Gmail API settings: #{missing.join(', ')}"
  end

  def fetch_access_token
    request = Net::HTTP::Post.new(TOKEN_URI)
    request.set_form_data(
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: @refresh_token,
      grant_type: "refresh_token"
    )

    response = perform_request(TOKEN_URI, request)
    unless success_response?(response)
      raise DeliveryError, "Gmail API token request failed (#{response.code}): #{response.body}"
    end

    JSON.parse(response.body).fetch("access_token")
  rescue JSON::ParserError, KeyError => e
    raise DeliveryError, "Gmail API token response parse failed: #{e.message}"
  end

  def send_message(access_token, mail)
    uri = URI(format(SEND_URI_TEMPLATE, user_id: CGI.escape(@user_id)))
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = JSON.generate(raw: Base64.urlsafe_encode64(mail.encoded, padding: false))

    perform_request(uri, request)
  end

  def perform_request(uri, request)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: @open_timeout,
      read_timeout: @read_timeout
    ) do |http|
      http.request(request)
    end
  end

  def success_response?(response)
    response.code.to_i.between?(200, 299)
  end
end
