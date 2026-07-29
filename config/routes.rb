NPlusInsight::Engine.routes.draw do
  root "detections#index"
  get "assets/overlay.css", to: "assets#stylesheet"
  get "assets/overlay.js", to: "assets#script"
  delete "detections", to: "detections#clear", as: :clear_detections
  resources :detections, only: [:show]
end
