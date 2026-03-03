Rails.application.routes.draw do
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  devise_for :users, controllers: {
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # ホーム（ガッツリ/サッパリのボタンがある）
  root "home#index"
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # 検索結果（料理1件をランダム表示）
  get "result", to: "dishes#result"

  # 詳細条件検索
  get "search/multiple_conditions", to: "search#multiple_conditions", as: :advanced_search
  # post 'search/advanced_result', to: 'search#advanced_result'

  # 検索履歴（ログインユーザーのみ）
  resources :search_histories, only: [ :index, :destroy ] do
    collection do
      get :trends
    end
  end

  # マイページ
  get "mypage", to: "mypages#show", as: :mypage
  patch "mypage", to: "mypages#update"

  # 管理者画面
  # namespace :admin do
  #   root 'dashboard#index'
  #   resources :dishes
  #   resources :categories
  # end
end
