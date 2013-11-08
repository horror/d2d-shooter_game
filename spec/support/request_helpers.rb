require 'em-websocket-request'

module Requests
  module JsonHelpers
    attr_reader :response
    attr_reader :ws_requests
    TEST_HOST = 'localhost'
    TEST_PORT = ':3000'
    TEST_SOCKET_PORT = ':8001'
    EPS = 1e-7

    def json_encode(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def json_decode(str)
      ActiveSupport::JSON.decode(str)
    end

    def xhr_wrap(json)
      #xhr :post, 'http://' + TEST_HOST + TEST_PORT, json, "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
      @response = RestClient.post 'http://' +  TEST_HOST + TEST_PORT, json, :content_type => "application/json; charset=utf-8"
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
      response.code.to_s.should == code && json_encode(resp).should == json_encode(expect)
    end

    def request_and_checking(action, params, body = {result: "ok"}, code = "200")
      send_request(action: action, params: params)
      check_response(body, code)
    end

    #Web Socket

    def web_socket_request(sid)
      request = EventMachine::WebsocketRequest.new(
          'ws://' + TEST_HOST + TEST_SOCKET_PORT,
          :inactivity_timeout => 100
      ).get

      request.callback {
        @ws_requests << request
        send_ws_request(request, "move", {sid: sid, dx: 0, dy: 0, tick: 0})
      }

      request.errback {
        puts "websocket connection problem"
      }

      return request
    end

    def close_socket(request = false, sid = "")
      @ws_requests.delete(request)
      request.stream { |message, type|
        send_ws_request(request, "move", {sid: sid, dx: 0, dy: 0, tick: json_decode(message)['tick']})
      }
      EM.stop if @ws_requests.length == 0
    end

    def send_ws_request(request, action, params)
      request.send(json_encode({action: action, params: params}))
    end

    def new_params(dx, dy, params, is_inc)
      params['vx'], params['vy'] = is_inc ? new_velocity(dx, dy, params['vx'], params['vy']) :
          new_velocity(-params['vx'], params['vy'], params['vx'], params['vy'])
      params['x'] = (params['x'] + params['vx']).round(ACCURACY)
      params['y'] = (params['y'] + params['vy']).round(ACCURACY)
      return params
    end

    def should_eql(a,b)
      (a - b).abs.should < EPS
    end
  end
end