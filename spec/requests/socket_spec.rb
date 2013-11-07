require "spec_helper"

describe 'Socket server' do
  EPS = 1e-7

  sid_a = sid_b = ""
  map_id = game_id = 0
  def_params = {'vx' => 0.0, 'vy' => 0.0, 'x' => 2.5, 'y' => 0.5, 'hp' => 100}

  before(:all) do
    send_request(action: "startTesting", params: {})
    send_request(action: "signup", params: {login: "user_a", password: "password"})
    send_request(action: "signup", params: {login: "user_b", password: "password"})
    send_request(action: "signin", params: {login: "user_a", password: "password"})
    sid_a = json_decode(response.body)["sid"]
    send_request(action: "signin", params: {login: "user_b", password: "password"})
    sid_b = json_decode(response.body)["sid"]
    send_request(action: "uploadMap", params: {sid: sid_a, name: "New map", maxPlayers: 10,
                                               map: ['1.$.2', '.3.1.', '#3.#.', '2...#']})
    send_request(action: "getMaps", params: {sid: sid_a})
    map_id = json_decode(response.body)["maps"][0]["id"]
    send_request(action: "createGame", params: {sid: sid_a, name: "New game", map: map_id, maxPlayers: 10})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"][0]["id"]
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
  end

  it "player spawn" do
    EM.run do
      request = webSocketRequest("move", {sid: sid_a, dx: 0, dy: 0})

      request.stream { |message, type|
        json_decode(message)['players'][0].should == check_arr
        EM.stop_event_loop
      }
    end
  end

  it "+/- one step move" do
    EM.run do
      request = webSocketRequest("move", {sid: sid_a, dx: 1, dy: 0})
      num = 0
      request.stream { |message, type|
        arr = json_decode(message)
        if arr['players'][0]['vx'] < EPS && arr['players'][0]['vy'] < EPS #Ждем
          case num
            when 0
              num += 1
              arr['players'][0]['x'].should > check_arr['x']
              (arr['players'][0]['y'] -  check_arr['y']).should < EPS
              request.send(json_encode({action: "move", params: {sid: sid_a, dx: -1, dy: 0, tick: arr['tick']}}))
            when 1
              num += 1
              (arr['players'][0]['x'] - check_arr['x']).should < EPS
              (arr['players'][0]['y'] -  check_arr['y']).should < EPS
            when 2
              EM.stop_event_loop
          end
        end
      }
    end
  end

  it "tick" do
    EM.run do
      request = webSocketRequest("move", {sid: sid_a, dx: 0, dy: 0})
      tick = -1
      counter = 0
      request.stream { |message, type|
        arr = json_decode(message)
        if tick != -1
          arr['tick'].should == tick + 1
          counter += 1
          EM.stop_event_loop if counter == 10
        end
        tick = arr['tick']
        request.send(json_encode({action: "move", params: {sid: sid_a, dx: 0, dy: 0, tick: arr['tick']}}))
      }
    end
  end
end
