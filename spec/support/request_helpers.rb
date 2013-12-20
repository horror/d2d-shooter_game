require 'em-websocket-request'

module Requests
  module JsonHelpers
    attr_reader :response
    attr_reader :ws_requests

    def json_encode(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def json_decode(str)
      ActiveSupport::JSON.decode(str)
    end

    def xhr_wrap(json)
      #xhr :post, 'http://' + TEST_HOST + TEST_PORT, json, "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
      @response = RestClient.post 'http://' + Settings.host + Settings.port, json, :content_type => "application/json; charset=utf-8"
    end

    def send_request(obj)
      xhr_wrap(json_encode(obj)) #local
    end

    def send_request_json(json)
      xhr_wrap(json)
    end

    def check_response(expect, code)
      resp = json_decode(response.body).inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo} #string keys to symbol
      resp.delete(:message)
      response.code.to_s.should == code && resp.should == expect
    end

    def request_and_checking(action, params, body = {result: "ok"}, code = "200")
      send_request(action: action, params: params)
      check_response(body, code)
    end

    #Web Socket

    def web_socket_request(sid)
      request = EventMachine::WebsocketRequest.new(
          'ws://' + Settings.host + Settings.web_socket_port,
          inactivity_timeout: 5,
          connect_timeout: 5
      ).get

      request.callback {
        @ws_requests << request
        send_ws_request(request, "move", {sid: sid, dx: 0, dy: 0, tick: 0})
      }

      request.disconnect{
        EM.stop
      }

      request.errback {
        puts "websocket connection problem"
      }

      return request
    end

    def close_socket(request = false, sid = "")
      @ws_requests.delete(request)
      request.stream { |message, type|
        send_ws_request(request, "empty", {sid: sid, tick: json_decode(message)['tick']})
      }
      EM.stop if @ws_requests.length == 0
    end

    def send_ws_request(request, action, params)
      request.send(json_encode({action: action, params: params}))
    end

    def should_be_true(expression, info)
      expression.should be_true, info
    end

    def should_eql(got, exp, info = "")
      info = info == "" ? "" : info + "\n"
      should_be_true((got - exp).abs < Settings.eps, "#{info}expected: #{exp}\n\tgot: #{got}")
    end
  end
end
