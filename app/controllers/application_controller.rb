class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  after_action :track_page_view

  private

  def track_page_view
    return unless request.get?
    return unless response.successful?
    return unless response.media_type == "text/html"
    return if controller_path.start_with?("admin/")
    return if respond_to?(:turbo_frame_request?, true) && turbo_frame_request?
    return unless respond_to?(:ahoy, true)

    track_analytics_event("page_view", {
      path: request.path,
      controller: controller_path,
      action: action_name
    })
  end

  def track_search_performed(mode:, params_hash:, result_found:)
    return unless respond_to?(:ahoy, true)

    track_analytics_event("search_performed", {
      search_mode: mode,
      query_params: params_hash,
      result_found: result_found
    })
  end

  def track_analytics_event(name, properties)
    ahoy.track(name, properties)
  rescue ActiveRecord::ConnectionNotEstablished, PG::Error => e
    Rails.logger.warn("[analytics] skipped #{name}: #{e.class}: #{e.message}")
  end
end
