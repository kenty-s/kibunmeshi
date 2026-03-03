class SearchController < ApplicationController
  before_action :disable_search_page_cache, only: :multiple_conditions

  def multiple_conditions
    @selected_conditions = search_params.compact_blank
    return if @selected_conditions.blank?

    @dishes = Dish.search_by_conditions(@selected_conditions)
    @dish = @dishes.sample
    return redirect_to root_path, alert: "条件に合う料理が見つかりませんでした" if @dish.nil?

    save_history(@selected_conditions, @dish)  # 呼び出し名
    render "dishes/result"
  end

  private

  def search_params
    permitted = params.permit(
      :keyword, :category, :scene, :time_of_day, :season, :genre,
      :spice_name, :spice_names, :taste
    )
    permitted[:spice_name] = permitted[:spice_name].presence || permitted.delete(:spice_names)
    permitted
  end

  def save_history(params_hash, dish)
    return unless current_user
    current_user.search_histories.create!(
      query_params: params_hash,
      dish: dish,
      executed_at: Time.current
    )
  end

  def disable_search_page_cache
    response.headers["Cache-Control"] = "no-store"
  end
end
