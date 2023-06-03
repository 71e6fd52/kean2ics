# frozen_string_literal: true

Rails.application.routes.draw do
  root 'schedule#login'

  get 'schedule/login'
  post 'schedule/login', to: 'schedule#perform_login'
  get 'schedule/choose'
  get 'schedule/logout'
  get 'schedule/generate/:term', to: 'schedule#generate'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
