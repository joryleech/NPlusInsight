NPlusInsight::Engine.routes.draw do
  root "detections#index"
  get "assets/overlay.css", to: "assets#stylesheet"
  get "assets/overlay.js", to: "assets#script"
  resources :detections, only: [:show]
end
