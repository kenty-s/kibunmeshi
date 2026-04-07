# frozen_string_literal: true

namespace :admin do
  desc "Ensure an admin user exists from ADMIN_* environment variables"
  task ensure_user: :environment do
    result = Admin::EnsureUser.new.call
    puts result.message
  rescue Admin::EnsureUser::ConfigurationError => e
    abort e.message
  end
end
