module NPlusInsight
  class Engine < ::Rails::Engine
    isolate_namespace NPlusInsight

    initializer "n_plus_insight.middleware" do |app|
      Subscriber.install!
      app.middleware.insert_after ActionDispatch::RequestId, NPlusInsight::Middleware
    end

    initializer "n_plus_insight.routes" do |app|
      app.routes.append do
        mount NPlusInsight::Engine => NPlusInsight.configuration.mount_path
      end
    end
  end
end
