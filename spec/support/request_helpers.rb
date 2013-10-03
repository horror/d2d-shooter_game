module Requests
  module JsonHelpers
    def json_encode(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def json_decode(str)
      ActiveSupport::JSON.decode(str)
    end

    def send_request(obj)
      xhr :post, "/", json_encode(obj), "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
    end

    def request_and_checking(action, params, body = {result: "ok"}, code = "200")
      send_request(action: action, params: params)
      response.code.should == code && response.body.should == json_encode(body)
    end
  end
end