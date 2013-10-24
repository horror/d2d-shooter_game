require "spec_helper"
require 'em-websocket-request'

describe 'Socket server' do

  TEST_HOST = 'localhost'
  TEST_PORT = ':8080'
  EPS = 1e-7

  sid_a = sid_b = ""
  map_id = game_id = 0
  check_arr = {'vx' => 0.0, 'vy' => 0.0, 'x' => 2.5, 'y' => 0.5}

  def webSocketRequest()
    request = EventMachine::WebsocketRequest.new('ws://' + TEST_HOST + TEST_PORT).get

    request.errback {
      puts "[websocket] problem connecting (will retry)"
      EM.stop_event_loop
    }
    return request
  end

  before(:all) do
    send_request(action: "startTesting", params: {})
    send_request(action: "signup", params: {login: "user_a", password: "password"})
    send_request(action: "signup", params: {login: "user_b", password: "password"})
    send_request(action: "signin", params: {login: "user_a", password: "password"})
    sid_a = json_decode(response.body)["sid"]
    send_request(action: "signin", params: {login: "user_b", password: "password"})
    sid_b = json_decode(response.body)["sid"]
    send_request(action: "uploadMap", params: {sid: sid_a, name: "New map", maxPlayers: 10,
                                               map: ['1.$.2', '#3.1.', '#3.#.', '2...#']})
    send_request(action: "getMaps", params: {sid: sid_a})
    map_id = json_decode(response.body)["maps"][0]["id"]
    send_request(action: "createGame", params: {sid: sid_a, name: "New game", map: map_id, maxPlayers: 10})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"][0]["id"]
    send_request(action: "joinGame", params: {sid: sid_a, game: game_id})
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
  end

  it "player spawn" do
    EM.run do
      request = webSocketRequest()

      request.callback {
        request.send(json_encode({sid: sid_a, action: "move", dx: 0, dy: 0}))
      }

      request.stream { |message, type|
        json_decode(message)['players'][0].should == check_arr
        EM.stop_event_loop
      }
    end
  end

  it "action one step move" do
    EM.run do
      request = webSocketRequest()

      request.callback {
        request.send(json_encode({sid: sid_a, action: "move", dx: 1, dy: 1}))
        request.send(json_encode({sid: sid_a, action: "move", dx: 1, dy: 1}))
      }

      num = 0
      request.stream { |message, type|
        arr = json_decode(message)
        arr['players'][0]['y'].should > check_arr['y']
        arr['players'][0]['x'].should > check_arr['x']
        EM.stop_event_loop
      }
    end
  end

  it "player teleport" do
    EM.run do
      request = webSocketRequest()

      request.callback {
        for i in 0..10
          request.send(json_encode({sid: sid_a, action: "move", dx: 1, dy: 1}))
        end
      }

      request.stream { |message, type|
        arr = json_decode(message)['players'][0]
        if arr['vx'] < EPS
          arr['y'].should == 3.5
          (arr['x'].should - 4.5).should < EPS
          EM.stop_event_loop
        end
      }
    end
  end
end
