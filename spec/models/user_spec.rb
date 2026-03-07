require 'rails_helper'

RSpec.describe User, type: :model do
  include ActiveJob::TestHelper

  around do |example|
    original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear
    example.run
  ensure
    clear_enqueued_jobs
    clear_performed_jobs
    ActionMailer::Base.deliveries.clear
    ActiveJob::Base.queue_adapter = original_queue_adapter
  end

  describe '.send_reset_password_instructions' do
    it 'enqueues the reset password email outside production and updates the reset token' do
      user = FactoryBot.create(:user)

      expect do
        User.send_reset_password_instructions(email: user.email)
      end.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      expect(user.reload.reset_password_token).to be_present
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.size).to eq(1)
    end
  end
end
