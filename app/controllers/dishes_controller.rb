class DishesController < ApplicationController
  def result
    category_name = result_params[:category]

    # カテゴリ名からランダムに1件取得
    @dish = Dish.random_by_category(category_name)

    # 検索条件に合う料理がない場合の処理
    if @dish.nil?
      flash[:alert] = "条件に合う料理が見つかりませんでした"
      redirect_to root_path
      return
    end

    save_search_history(result_params.to_h, @dish)
    # 料理が見つかった場合は(result.html.erb)を表示
  end

  private

  def result_params
    params.permit(:category)
  end

  def save_search_history(params_hash, dish)
    return unless current_user
    current_user.search_histories.create!(
      query_params: params_hash,
      dish: dish,
      executed_at: Time.current
    )
  end
end
