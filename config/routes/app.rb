resources :categories, only: :index
resources :assets, only: %i[index show], param: :ticker
resources :balances, only: %i[index show create update destroy]
resources :entries, only: %i[index show create update destroy]
resources :entry_series, only: :create
resources :investment_transactions, only: %i[index show create update destroy]
resources :investment_positions, only: :update, param: :ticker
resource :portfolio, only: :show do
  get :history
end
resource :projection, only: :show do
  post :simulation
end

namespace :admin do
  resource :metrics, only: :show
  resources :categories, only: %i[index create update]
end

namespace :me do
  resource :notification_settings, only: %i[show update] do
    post :unsubscribe
  end
end
