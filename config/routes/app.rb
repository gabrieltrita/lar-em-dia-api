resources :categories, only: :index
resources :balances, only: %i[index show create update destroy]
resources :entries, only: %i[index show create update destroy]
resources :entry_series, only: :create
resource :projection, only: :show

namespace :admin do
  resource :metrics, only: :show
end
