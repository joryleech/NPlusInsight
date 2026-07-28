module NPlusInsight
  class DetectionsController < ApplicationController
    def index
      @detections = Store.all
    end

    def show
      @detection = Store.find(params[:id])
      return head :not_found unless @detection
    end
  end
end
