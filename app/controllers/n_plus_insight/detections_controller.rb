module NPlusInsight
  class DetectionsController < ApplicationController
    def index
      @detections = Store.all
    end

    def show
      @detection = Store.find(params[:id])
      return head :not_found unless @detection
    end

    def clear
      Store.clear
      redirect_to root_path, status: :see_other, notice: "Stored detections cleared."
    end
  end
end
