Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      post 'signup', to: 'authentication#signup'
      post 'login', to: 'authentication#login'
      get 'profile', to: 'authentication#profile'

      post 'files/presigned_url', to: 'files#create_presigned_url'
      post 'files/:id/mark_uploaded', to: 'files#mark_uploaded'
      get 'files/:id/download', to: 'files#download'
      post 'files/:id/reprocess', to: 'files#reprocess'
      resources :files, only: [:index]

      # Simulated S3 PUT uploads
      put 'local_s3_uploads', to: 'local_s3_uploads#create'

      # Lambda webhook (no JWT auth, uses shared secret)
      post 'processing/webhook', to: 'processing_webhook#handle'

      # Sharing links
      resources :share_links, only: [:create]
      get 'shares/:token', to: 'share_links#show'
      post 'shares/:token/validate', to: 'share_links#validate_passcode'
    end
  end
end
