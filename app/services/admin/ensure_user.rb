# frozen_string_literal: true

module Admin
  class EnsureUser
    class ConfigurationError < StandardError; end

    Result = Struct.new(:status, :user, :message, keyword_init: true)

    def initialize(email: ENV["ADMIN_EMAIL"], password: ENV["ADMIN_PASSWORD"], name: ENV["ADMIN_NAME"], force_password_update: ENV["ADMIN_FORCE_PASSWORD_UPDATE"])
      @email = email.to_s.strip.downcase
      @password = password.to_s
      @name = name.to_s.strip
      @force_password_update = ActiveModel::Type::Boolean.new.cast(force_password_update)
    end

    def call
      return Result.new(status: :skipped, user: nil, message: "ADMIN_EMAIL is not set. Skipping admin bootstrap.") if email.blank? && password.blank?
      raise ConfigurationError, "ADMIN_EMAIL is required when ADMIN_PASSWORD is set." if email.blank?

      user = User.find_or_initialize_by(email: email)
      raise ConfigurationError, "ADMIN_PASSWORD is required to create admin user #{email}." if user.new_record? && password.blank?

      created = user.new_record?
      user.name = resolved_name(user)
      user.admin = true
      apply_password(user)

      changed = user.changed?
      user.save! if changed

      Result.new(status: resolve_status(created, changed), user: user, message: build_message(created, changed, user))
    end

    private

    attr_reader :email, :password, :name

    def resolved_name(user)
      return name if name.present?
      return user.name if user.name.present?

      "管理者"
    end

    def apply_password(user)
      return if password.blank?
      return unless user.new_record? || force_password_update? || user.encrypted_password.blank?

      user.password = password
      user.password_confirmation = password
    end

    def resolve_status(created, changed)
      return :created if created
      return :updated if changed

      :unchanged
    end

    def build_message(created, changed, user)
      if created
        "Created admin user: #{user.email}"
      elsif changed
        "Updated admin user: #{user.email}"
      else
        "Admin user already up-to-date: #{user.email}"
      end
    end

    def force_password_update?
      @force_password_update
    end
  end
end
