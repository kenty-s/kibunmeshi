Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }
  # ========================================
  # MVP機能（現在実装中）
  # ========================================

  # ホーム（ガッツリ/サッパリのボタンがある）
  root "home#index"

  # 検索結果（料理1件をランダム表示）
  get "result", to: "dishes#result"

  # ========================================
  # MVP後の拡張機能（ルーティングのみ先行定義）
  # ========================================

  # 詳細条件検索
  get "search/multiple_conditions", to: "search#multiple_conditions", as: :advanced_search
  # post 'search/advanced_result', to: 'search#advanced_result'

  # 検索履歴（ログインユーザーのみ）
  resources :search_histories, only: [ :index, :destroy ] do
    collection do
      get :trends
    end
  end

  # SNS投稿（X投稿機能）
  # post 'share/twitter', to: 'share#twitter'

  # 管理者画面
  # namespace :admin do
  #   root 'dashboard#index'
  #   resources :dishes
  #   resources :categories
  # end
end
