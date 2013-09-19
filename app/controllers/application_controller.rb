class ApplicationController < ActionController::Base
  include AuthHelper
  include ChatHelper

  def index
    send(params["application"]["action"], params["application"]["params"])
    @response_json = ActiveSupport::JSON.encode(@response_obj)
    render :json => @response_json
  end

end
