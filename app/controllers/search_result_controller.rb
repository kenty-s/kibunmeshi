class SearchResultController < ApplicationController
  def show
    # 複数条件検索の結果をランダムで1つ取得
    @dish = search_dishes.sample

    # 検索条件に合う料理がない場合の処理
    if @dish.nil?
      flash[:alert] = "条件に合う料理が見つかりませんでした"
      redirect_to root_path
    end
  end

  private

  def search_dishes
    # 検索条件を組み立て
    dishes = Dish.all

    # パラメータに応じて検索条件を追加
    dishes = dishes.where(条件) if search_params[:条件].present?

    dishes
  end

  def search_params
    params.permit(:条件)
  end
end
