class ApplicationController < ActionController::Base
  include ApplicationHelper
  include MessageHelper
  include AuthHelper
  include ChatHelper
  include GameHelper
  include MapHelper
  include ValidationHelper

  def index
    response.headers["Access-Control-Allow-Origin"] = '*'
    response.headers["Access-Control-Allow-Headers"] = 'Content-Type, X-Requested_with'
    req = params['application']
    if req != nil
      begin
        raise BadParamsError.new(badJSON) unless !req.include?("json parser exception")
        raise BadParamsError.new(badParams) unless req.include?("action")

        req["params"] = req.include?("params") ? req["params"] : {}
        check_action_params(req["action"], req["params"])
        send(req["action"], req["params"])
      rescue
      ensure
          render :json => ActiveSupport::JSON.encode(@response_obj == nil ? "fatalError" : @response_obj)
      end
    end
  end

end
