resources :categories, only: :index
resources :balances, only: %i[index show create update destroy]
resources :entries, only: %i[index show create update destroy]
resource :projection, only: :show
