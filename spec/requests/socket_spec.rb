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
                                               map: ['1.$.2', '#####', '..31.', '#####', '.3.#.', '#####', '#2..#']})
    send_request(action: "getMaps", params: {sid: sid_a})
    map_id = json_decode(response.body)["maps"][0]["id"]
    send_request(action: "createGame", params: {sid: sid_a, name: "New game", map: map_id, maxPlayers: 10})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"][0]["id"]
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
end

  before do
    @ws_requests = Array.new
  end

  def def_request (indx = 0, sid, check_limit, send_limit, x_val, y_val, vx_val, vy_val, dx_rule, dy_rule, &checking)
    request = web_socket_request(sid)
    counter = 0
    checking ||= lambda{ |params|
        should_eql(params['x'], x_val)
        should_eql(params['y'], y_val)
        should_eql(params['vx'], vx_val)
        should_eql(params['vy'], vy_val)
    }
    request.stream { |message, type|
      tick = json_decode(message)['tick']
      params = json_decode(message)['players'][indx]
      if counter == check_limit
        checking.call(params)
        close_socket(request, sid)
      end
      #puts "Cnt = #{counter}, params = #{params}"
      send_ws_request(request, "move", {sid: sid, dx: dx_rule.call(params, counter), dy: dy_rule.call(params, counter), tick: tick}) if counter < send_limit
      counter += 1
    }
  end

  it "players spawn" do
    EM.run do
      request_a = web_socket_request(sid_a)
      request_b = web_socket_request(sid_b)
      request_a.stream { |message, type|
        json_decode(message)['players'][0].should == def_params
        close_socket(request_a, sid_a)
      }
      request_b.stream { |message, type|
        json_decode(message)['players'].should == [def_params, def_params]
        close_socket(request_b, sid_b)
      }
    end
  end

  it "+/- one step move" do
    EM.run do
      request = web_socket_request(sid_a)
      num = 0
      request.stream { |message, type|
        arr = json_decode(message)
        if arr['players'][0]['vx'] < EPS
          case num
            when 0
              num += 1
              send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
            when 1
              num += 1
              arr['players'][0]['x'].should > def_params['x']
              should_eql(arr['players'][0]['y'], def_params['y'])
              send_ws_request(request, "move", {sid: sid_a, dx: -1, dy: 0, tick: arr['tick']})
            when 2
              num += 1
              should_eql(arr['players'][0]['x'], def_params['x'])
              should_eql(arr['players'][0]['y'], def_params['y'])
            when 3
              close_socket(request, sid_a)
          end
        end
      }
    end
  end

  it "inc/dec velocity" do
    EM.run do
      request = web_socket_request(sid_a)
      is_move = true
      check_arr = def_params
      request.stream { |message, type|
        arr = json_decode(message)
        check_arr.should == arr['players'][0]
        check_arr = new_params(1, 0, check_arr, is_move)
        if is_move
          send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
          is_move = check_arr['vx'] <= 0.2
        end
        close_socket(request, sid_a) if !is_move && check_arr['vx'] < EPS
      }
    end
  end

  it "tick" do
    EM.run do
      request = web_socket_request(sid_a)
      tick = -1
      counter = 0
      request.stream { |message, type|
        arr = json_decode(message)
        if tick != -1
          arr['tick'].should == tick + 1
          counter += 1
          close_socket(request, sid_a) if counter == 10
        end
        tick = arr['tick']
        send_ws_request(request, "move", {sid: sid_a, dx: 0, dy: 0, tick: arr['tick']})
      }
    end
  end

  it "stay at tp" do
    EM.run do
      def_request(sid_a, 10, 4, 0.0, 0.0, 0.0, 0.0, lambda{|prms, cnt| 1}, lambda{|prms, cnt| 0}){|params|
          should_eql(params['y'], 6.5)
          params['x'].should < 2
      }
    end
  end

  it "to right wall" do
    EM.run { def_request(sid_a, 15, 10, 3.5, 6.5, 0.0, 0.0, lambda{|prms, cnt| 1}, lambda{|prms, cnt| 0}) }
  end

  it "to left wall" do
    EM.run { def_request(sid_a, 15, 15, 1.5, 6.5, 0.0, 0.0, lambda{|prms, cnt| cnt > 3 ? -1 : 1}, lambda{|prms, cnt| 0}) }
  end

  it "left border" do
    EM.run { def_request(sid_a, 10, 10, 0.5, 4.5, 0.0, 0.0, lambda{|prms, cnt| -1}, lambda{|prms, cnt| 0}) }
  end

  it "right border" do
    EM.run { def_request(sid_a, 15, 15, 4.5, 2.5, 0.0, 0.0, lambda{|prms, cnt| cnt > 3 ? 1 : -1}, lambda{|prms, cnt| 0}) }
  end

  it "two players run" do
    EM.run {
      def_request(sid_a, 30, 30, 3.5, 6.5, 0.0, 0.0, lambda{|prms, cnt| cnt > 10 ? 1 : -1}, lambda{|prms, cnt| 0})
      def_request(1, sid_b, 30, 30, 0.5, 4.5, 0.0, 0.0, lambda{|prms, cnt| cnt > 10 ? -1 : 1}, lambda{|prms, cnt| 0})
    }
  end

  it "max velocity" do
    EM.run { def_request(sid_a, 21, 21, 1.5, 6.5, 1.0, 0.0, lambda{|prms, cnt| cnt > 10 ? 1 : -1}, lambda{|prms, cnt| 0}) }
  end

end
