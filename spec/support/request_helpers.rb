module Requests
  module JsonHelpers

    attr_reader :response

    def json_encode(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def json_decode(str)
      ActiveSupport::JSON.decode(str)
    end

    def xhr_wrap(json)
      xhr :post, "http://localhost:3000", json, "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
      #@response = RestClient.post "http://localhost:3000", json, :content_type => "application/json; charset=utf-8"
    end

    def send_request(obj)
      xhr_wrap(json_encode(obj)) #local
    end

    def send_request_json(json)
      xhr_wrap(json)
    end

    def check_response(expect, code)
      resp = json_decode(response.body)
      resp.delete("message")
      response.code.to_s.should == code && json_encode(resp) == json_encode(expect)
    end


    def request_and_checking(action, params, body = {result: "ok"}, code = "200")
      send_request(action: action, params: params)
      check_response(body, code)
    end
  end
end