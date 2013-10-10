class ApplicationController < ActionController::Base
  include ApplicationHelper
  include MessageHelper
  include AuthHelper
  include ChatHelper
  include GameHelper
  include ValidationHelper

  def index
    response.headers["Access-Control-Allow-Origin"] = '*'
    response.headers["Access-Control-Allow-Headers"] = 'Content-Type, X-Requested_with'
    if params['application'] != nil
      begin
        check_action_params(params["application"]["action"], params["application"]["params"])
        send(params["application"]["action"], params["application"]["params"])
      rescue
      ensure
          @response_json = ActiveSupport::JSON.encode(@response_obj)
          render :json => @response_json
      end
    end
  end

end
