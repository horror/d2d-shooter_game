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

  def def_request (params, &checking)
    params_list = [:dx_rule, :dy_rule, :index, :x, :y, :vx, :vy, :check_limit, :send_limit]
    params_list.each {|i| params[i] ||= 0 }
    request = web_socket_request(params[:sid])
    p_tick = 0
    checking ||= lambda{ |player|
        should_eql(player['x'], params[:x])
        should_eql(player['y'], params[:y])
        should_eql(player['vx'], params[:vx])
        should_eql(player['vy'], params[:vy])
    }
    request.stream { |message, type|
      tick = json_decode(message)['tick']
      player = json_decode(message)['players'][params[:index]]
      puts "Cnt = #{p_tick}, params = #{player}, Tick = #{tick}"
      if p_tick == params[:check_limit]
        checking.call(player)
        close_socket(request, params[:sid])
      end
      dx = params[:dx_rule].kind_of?(Proc) ? params[:dx_rule].call(p_tick, player) : params[:dx_rule]
      dy = params[:dy_rule].kind_of?(Proc) ? params[:dy_rule].call(p_tick, player) : params[:dy_rule]
      send_ws_request(request, "move", {sid: params[:sid], dx: dx, dy: dy, tick: tick}) if p_tick < params[:send_limit]
      p_tick += 1
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
      p_tick = 0
      request.stream { |message, type|
        arr = json_decode(message)
        player = arr['players'][0]
        if player['vx'] < EPS
          case p_tick
            when 0
              send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
            when 1
              player['x'].should > def_params['x']
              should_eql(player['y'], def_params['y'])
              send_ws_request(request, "move", {sid: sid_a, dx: -1, dy: 0, tick: arr['tick']})
            when 2
              should_eql(player['x'], def_params['x'])
              should_eql(player['y'], def_params['y'])
            when 3
              close_socket(request, sid_a)
          end
          p_tick += 1
        end
      }
    end
  end

  it "inc/dec velocity" do
    EM.run do
      request = web_socket_request(sid_a)
      is_moving = true
      curr_player_params = def_params
      request.stream { |message, type|
        arr = json_decode(message)
        player = arr['players'][0]
        curr_player_params.should == player
        curr_player_params = new_params(1, 0, curr_player_params, is_moving)
        if is_moving
          send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
          is_moving = curr_player_params['vx'] <= 0.2
        end
        close_socket(request, sid_a) if !is_moving && curr_player_params['vx'] < EPS
      }
    end
  end

  it "tick" do
    EM.run do
      request = web_socket_request(sid_a)
      tick = -1
      p_tick = 0
      request.stream { |message, type|
        arr = json_decode(message)
        player = arr['players'][0]
        if tick != -1
          arr['tick'].should == tick + 1
          p_tick += 1
          close_socket(request, sid_a) if p_tick == 10
        end
        tick = arr['tick']
        send_ws_request(request, "move", {sid: sid_a, dx: 0, dy: 0, tick: arr['tick']})
      }
    end
  end

  it "stay at tp" do
    EM.run { def_request( {sid: sid_a, check_limit: 10, send_limit: 4, x:1.6, y: 6.5, dx_rule: 1} ) }
  end

  it "to right wall" do
    EM.run { def_request( {sid: sid_a, check_limit: 15, send_limit: 10, x: 3.5, y: 6.5, dx_rule: 1} ) }
  end

  it "to left wall" do
    EM.run {
      def_request( {sid: sid_a, check_limit: 15, send_limit: 15, x: 1.5, y: 6.5, dx_rule: Proc.new{|p_tick| p_tick > 3 ? -1 : 1}} )
    }
  end

  it "left border" do
    EM.run { def_request( {sid: sid_a, check_limit: 10, send_limit: 10, x: 0.5, y: 4.5, dx_rule: -1} ) }
  end

  it "right border" do
    EM.run {
      def_request( {sid: sid_a, check_limit: 15, send_limit: 15, x: 4.5, y: 2.5, dx_rule: Proc.new{|p_tick| p_tick > 3 ? 1 : -1}} )
    }
  end

  it "two players run" do
    EM.run {
      def_request( {sid: sid_a, check_limit: 25, send_limit: 25, x: 3.5, y: 6.5, dx_rule: Proc.new{|p_tick| p_tick > 10 ? 1 : -1}} )
      def_request( {index: 1, sid: sid_b, check_limit: 25, send_limit: 25, x: 0.5, y: 4.5, dx_rule: Proc.new{|p_tick| p_tick > 10 ? -1 : 1}} )
    }
  end

  it "max velocity" do
    EM.run {
      def_request( {sid: sid_a, check_limit: 21, send_limit: 21, x: 1.5, y: 6.5, vx: 1.0, dx_rule: Proc.new{|p_tick| p_tick > 10 ? 1 : -1}} )
    }
  end
end
