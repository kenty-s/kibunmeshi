require "rails_helper"

RSpec.describe GmailApiDelivery do
  subject(:delivery_method) do
    described_class.new(
      client_id: "client-id",
      client_secret: "client-secret",
      refresh_token: "refresh-token"
    )
  end

  let(:mail) do
    Mail.new do
      from "noreply.kibunmeshi@gmail.com"
      to "user@example.com"
      subject "Reset"
      body "hello"
    end
  end

  let(:http) { instance_double(Net::HTTP) }
  let(:token_response) { instance_double("Net::HTTPResponse", code: "200", body: '{"access_token":"token-123"}') }
  let(:send_response) { instance_double("Net::HTTPResponse", code: "200", body: '{"id":"message-123"}') }

  it "exchanges a refresh token and sends the message" do
    requests = []
    responses = [ token_response, send_response ]

    allow(Net::HTTP).to receive(:start) do |*_args, **_kwargs, &block|
      block.call(http)
    end
    allow(http).to receive(:request) do |request|
      requests << request
      responses.shift
    end

    delivery_method.deliver!(mail)

    expect(requests.size).to eq(2)
    expect(requests.last["Authorization"]).to eq("Bearer token-123")
    expect(JSON.parse(requests.last.body)).to include("raw")
  end

  it "raises when mandatory settings are missing" do
    expect {
      described_class.new.deliver!(mail)
    }.to raise_error(GmailApiDelivery::DeliveryError, /Missing Gmail API settings/)
  end
end
