resources :categories, only: :index
resources :balances, only: %i[index show create update destroy]
resources :entries, only: %i[index show create update destroy]
resources :entry_series, only: :create
resource :projection, only: :show do
  post :simulation
end

namespace :admin do
  resource :metrics, only: :show
end

namespace :me do
  resource :notification_settings, only: %i[show update] do
    post :unsubscribe
  end
end
