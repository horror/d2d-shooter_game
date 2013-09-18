class ApplicationController < ActionController::Base
  include AuthHelper

  def index
    request_obj = ActiveSupport::JSON.decode(params[:_json])
    send(request_obj["action"], request_obj["params"])
    @response_json = ActiveSupport::JSON.encode(@response_obj)
  end

end
