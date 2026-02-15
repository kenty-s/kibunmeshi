class SearchController < ApplicationController
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
    params.permit(:keyword, :category, :time_of_day, :season, :mood, :genre, :cooking_style, :healthiness_type, :spice_name)
  end

  def save_history(params_hash, dish)
    return unless current_user
    current_user.search_histories.create!(
      query_params: params_hash,
      dish: dish,
      executed_at: Time.current
    )
  end
end
