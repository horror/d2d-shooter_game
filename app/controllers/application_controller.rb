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
      if req.include?("badJSON")
        render :json => ActiveSupport::JSON.encode({result: "badJSON"})
        return
      end

      if !req.include?("action")
        render :json => ActiveSupport::JSON.encode({result: "badParams"})
        return
      end

      begin
        req["params"] = req.include?("params") ? req["params"] : {}
        check_action_params(req["action"], req["params"])
        send(req["action"], req["params"])
      rescue
      ensure
          render :json => ActiveSupport::JSON.encode(@response_obj)
      end
    end
  end

end
