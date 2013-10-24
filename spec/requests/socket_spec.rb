require "spec_helper"
require 'em-websocket-request'

describe 'Socket server' do

  sid_a = sid_b = ""
  map_id = game_id = 0
  TEST_HOST = 'localhost'
  TEST_PORT = ':8080'

  def webSocketRequest()
    request = EventMachine::WebsocketRequest.new('ws://' + TEST_HOST + TEST_PORT).get

    request.errback {
      puts "[websocket] problem connecting (will retry)"
      EM.stop_event_loop
    }
    return request
  end

  def getCheckArr(y)
    case y
      when 0.5
        return {'vx' => 0.0, 'vy' => 0.0, 'x' => 1.5, 'y' => 0.5}
      when 2.5
        return {'vx' => 0.0, 'vy' => 0.0, 'x' => 0.5, 'y' => 2.5}
      when 3.5
        return {'vx' => 0.0, 'vy' => 0.0, 'x' => 2.5, 'y' => 3.5}
    end
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
                                               map: ['1$.2.', '.3#1.', '$3.#.', '2.$.#']})
    send_request(action: "getMaps", params: {sid: sid_a})
    map_id = json_decode(response.body)["maps"][0]["id"]
    send_request(action: "createGame", params: {sid: sid_a, name: "New game", map: map_id, maxPlayers: 10})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"][0]["id"]
    send_request(action: "joinGame", params: {sid: sid_a, game: game_id})
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
  end

  it "player connection, random spawn" do
    EM.run do
      request = webSocketRequest()
      request.callback { request.send(json_encode({sid: sid_a, action: "move", dx: 0, dy: 0})) }

      request.stream { |chunk, type|
        #msg = request.process_data(chunk, type)
        arr = json_decode(chunk)[0]
        [0.5, 2.5, 3.5].include?(arr['y']).should == true
        check_arr = getCheckArr(arr['y'])
        arr.should == check_arr
        EM.stop_event_loop
      }
    end
  end

  it "action move" do
    EM.run do
      request = webSocketRequest()
      request.callback {
        for i in 0..10 do
          request.send(json_encode({sid: sid_a, action: "move", dx: 1, dy: 0}))
        end
      }
      counter = 0
      check_arr = {}
      request.stream { |chunk, type|
        counter += 1
        check_arr = getCheckArr(json_decode(chunk)[0]["y"]) if counter == 1
        if counter == 20
          arr = json_decode(chunk)[0]
          arr['y'].should == check_arr['y']
          arr['x'].should > check_arr['x'] + 0.5
          EM.stop_event_loop
        end
      }
    end
  end
end