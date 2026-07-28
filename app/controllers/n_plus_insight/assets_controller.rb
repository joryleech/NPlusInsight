module NPlusInsight
  class AssetsController < ApplicationController
    skip_forgery_protection

    ASSET_ROOT = NPlusInsight::Engine.root.join("app", "assets", "n_plus_insight")

    def stylesheet
      send_asset("overlay.css", "text/css")
    end

    def script
      send_asset("overlay.js", "application/javascript")
    end

    private

    def send_asset(name, type)
      response.headers["Cache-Control"] = "no-store"
      send_data File.binread(ASSET_ROOT.join(name).to_s), type: type, disposition: "inline"
    end
  end
end
