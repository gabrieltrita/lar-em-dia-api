resources :categories, only: %i[index create update destroy]
resources :assets, only: %i[index show], param: :ticker
resources :balances, only: %i[index show create update destroy]
resources :entries, only: %i[index show create update destroy]
resources :entry_series, only: :create
resources :investment_transactions, only: %i[index show create update destroy]
resources :investment_positions, only: :update, param: :ticker
resource :portfolio, only: :show do
  get :history
  get :income
  post :simulation
end
resources :asset_distributions, only: %i[index create update destroy]
resources :reserve_accounts, only: %i[index show create update destroy]
resources :reserve_movements, only: %i[index show create update destroy]
resource :reserve, only: %i[show update] do
  get :projection
end
resources :allocation_targets, only: %i[index create update destroy]
resources :allocations, only: %i[create destroy]
resource :allocation_plan, only: :show
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
