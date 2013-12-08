require "spec_helper"

describe 'Socket server' do

  sid_a = sid_b = ""
  map_id = game_id = 0
  def_params = {'vx' => 0.0, 'vy' => 0.0, 'x' => 2.5, 'y' => 0.5, 'hp' => 100, 'respawn' => 0, 'status' => "alive"}
  game_consts = {accel: 0.05, max_velocity: 0.5, gravity: 0.05, friction: 0.05}

  before(:all) do
    send_request(action: "startTesting", params: {websocketMode: "sync"})
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
    consts = {accel: game_consts[:accel], maxVelocity: game_consts[:max_velocity], gravity: game_consts[:gravity], friction: game_consts[:friction]}
    send_request(action: "createGame", params: {sid: sid_a, name: "New game", map: map_id, maxPlayers: 10, consts: consts})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"][0]["id"]
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
  end

  before do
    @ws_requests = Array.new
  end

  def check_player(got_player, expected_player)
    expected_player.map{|key, val| should_eql(got_player[key.to_s], val, key.to_s)}
  end

  @requests_file

  def load_requests_file(name, spawn, mode = "a")
    @requests_file = File.open("requests.txt", mode)
    @requests_file.puts(name)
    @requests_file.puts("{\"x\": #{spawn[:coord].x}, \"y\": #{spawn[:coord].y}}")
  end

  def def_request (params)
    params_list = [:dx_rule, :dy_rule, :index, :x, :y, :vx, :vy, :check_limit, :send_limit, :name]
    params_list.each {|i| params[i] ||= 0 }
    params[:action] ||= "move"
    request = web_socket_request(params[:sid])
    p_tick = 0
    params[:checking_proc] ||= Proc.new{ |player, p_tick, params|
      next false if p_tick != params[:check_limit]
      check_player(player, {x: params[:x], y: params[:y], vx: params[:vx], vy: params[:vy]})
      true
    }
    request.stream { |message, type|
      tick = json_decode(message)['tick']
      player = json_decode(message)['players'][params[:index]]
      puts "Sid = #{params[:sid][0..2]}, Cnt = #{p_tick}, params = #{player}, Tick = #{tick}" if params.include?(:log)
      close_socket(request, params[:sid]) if params[:checking_proc].call(player, p_tick, params)
      dx = params[:dx_rule].kind_of?(Proc) ? params[:dx_rule].call(p_tick, player) : params[:dx_rule]
      dy = params[:dy_rule].kind_of?(Proc) ? params[:dy_rule].call(p_tick, player) : params[:dy_rule]
      action = params[:action].kind_of?(Proc) ? params[:action].call(p_tick, player) : params[:action]
      action = "empty" if p_tick >= params[:send_limit]
      send_ws_request(request, action, arr = {sid: params[:sid], dx: dx, dy: dy, tick: tick})
      @requests_file.puts(json_encode({action: action, params: arr})) if params.include?(:make_file)
      p_tick += 1
    }
  end

  describe "simple movings, spawn, collisions: " do

    it "players spawn" do
      EM.run do
        request_a = web_socket_request(sid_a)
        request_b = web_socket_request(sid_b)
        request_a.stream { |message, type|
          json_decode(message)['players'][0].should == def_params.merge({"login" => "user_a"})
          send_ws_request(request_a, "empty", {sid: sid_a, tick: json_decode(message)['tick']})
          close_socket(request_a, sid_a)
        }
        request_b.stream { |message, type|
          json_decode(message)['players'].should == [def_params.merge({"login" => "user_a"}), def_params.merge({"login" => "user_b"})]
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
          if player['vx'].abs < Settings.eps
            case p_tick
              when 0
                send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
              when 1
                player['x'].should > def_params['x']
                should_eql(player['y'], def_params['y'], "coord.x")
                send_ws_request(request, "move", {sid: sid_a, dx: -1, dy: 0, tick: arr['tick']})
              when 2
                should_eql(player['x'], def_params['x'], "coord.x")
                should_eql(player['y'], def_params['y'], "coord.y")
                send_ws_request(request, "empty", {sid: sid_a, tick: arr['tick']})
              when 3
                close_socket(request, sid_a)
            end
            p_tick += 1
          else
            send_ws_request(request, "empty", {sid: sid_a, tick: arr['tick']})
          end
        }
      end
    end

    it "inc/dec velocity" do
      EM.run do
        request = web_socket_request(sid_a)
        is_moving = true
        curr_player = def_params
        request.stream { |message, type|
          arr = json_decode(message)
          player = arr['players'][0]
          should_eql(player['x'], curr_player['x'], "coord.x")
          should_eql(player['vx'], curr_player['vx'], "velocity.x")
          curr_player['vx'] += is_moving ? game_consts[:accel] : -game_consts[:friction]
          curr_player['x'] += curr_player['vx']
          if is_moving
            send_ws_request(request, "move", {sid: sid_a, dx: 1, dy: 0, tick: arr['tick']})
            is_moving = player['vx'] <= 0.1
          end
          send_ws_request(request, "empty", {sid: sid_a, tick: arr['tick']}) if !is_moving && player['vx'].abs >= Settings.eps
          close_socket(request, sid_a) if !is_moving && player['vx'].abs < Settings.eps
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
      EM.run { def_request( {sid: sid_a, check_limit: 15, send_limit: 6, x: 1.65, y: 6.5, dx_rule: 1} ) }
    end

    it "to right wall" do
      EM.run { def_request( {sid: sid_a, check_limit: 20, send_limit: 10, x: 3.5, y: 6.5, dx_rule: 1} ) }
    end

    it "to left wall" do
      EM.run {
        def_request( {sid: sid_a, check_limit: 15, send_limit: 15, x: 1.5, y: 6.5, dx_rule: Proc.new{|p_tick| p_tick > 5 ? -1 : 1}} )
      }
    end

    it "left border" do
      EM.run { def_request( {sid: sid_a, check_limit: 20, send_limit: 10, x: 0.5, y: 4.5, dx_rule: -1} ) }
    end

    it "right border" do
      EM.run {
        def_request( {sid: sid_a, check_limit: 20, send_limit: 20, x: 4.5, y: 2.5, dx_rule: Proc.new{|p_tick| p_tick > 5 ? 1 : -1}} )
      }
    end

    it "two players run" do
      EM.run {
        def_request( {sid: sid_a, check_limit: 40, send_limit: 40, x: 3.5, y: 6.5, dx_rule: Proc.new{|p_tick| p_tick > 15 ? 1 : -1}} )
        def_request( {index: 1, sid: sid_b, check_limit: 40, send_limit: 40, x: 0.5, y: 4.5, dx_rule: Proc.new{|p_tick| p_tick > 15 ? -1 : 1}} )
      }
    end

    it "max velocity" do
      EM.run {
        def_request( {sid: sid_a, check_limit: 30, send_limit: 30, x: 3.85, y: 0.5, vx: game_consts[:max_velocity],
                      dx_rule: Proc.new{|p_tick| p_tick > 15 ? 1 : -1}} )
      }
    end
  end

  def recreate_game(map, sid_a, sid_b, map_id, game_id, game_consts, index)
    send_request(action: "leaveGame", params: {sid: sid_a})
    send_request(action: "leaveGame", params: {sid: sid_b})
    send_request(action: "uploadMap", params: {sid: sid_a, name: "New map #{index}", maxPlayers: 10, map: map})
    send_request(action: "getMaps", params: {sid: sid_a})
    map_id = json_decode(response.body)["maps"]
    map_id = map_id[map_id.size - 1]["id"]
    consts = {accel: game_consts[:accel], maxVelocity: game_consts[:max_velocity], gravity: game_consts[:gravity], friction: game_consts[:friction]}
    send_request(action: "createGame", params: {sid: sid_a, name: "New game #{index}", map: map_id, maxPlayers: 10, consts: consts})
    send_request(action: "getGames", params: {sid: sid_a})
    game_id = json_decode(response.body)["games"]
    game_id = game_id[game_id.size - 1]["id"]
    send_request(action: "joinGame", params: {sid: sid_b, game: game_id})
  end

  describe "Gravity: " do

    spawns = [{coord: Point(5.5, 0.5), velocity: Point(0, 0)}, {coord: Point(0.5, 3.5), velocity: Point(0, 0)},
              {coord: Point(7.5, 3.5), velocity: Point(0, 0)}]

    before(:all) do
      map = ['.....$..',
             '####.#..',
             '........',
             '$......$',
             '#.#..###']
      recreate_game(map, sid_a, sid_b, map_id, game_id, game_consts, 2)
    end

    it "respawns order" do
      EM.run{ def_request( {sid: sid_a, x: spawns[0][:coord].x, y: spawns[0][:coord].y} ) }
      EM.run{ def_request( {sid: sid_a, x: spawns[1][:coord].x, y: spawns[1][:coord].y} ) }
      EM.run{
        def_request( {sid: sid_a, check_limit: 5, x: spawns[2][:coord].x, y: spawns[2][:coord].y} )
        def_request( {index: 1, sid: sid_b, x: spawns[0][:coord].x, y: spawns[0][:coord].y} )
      }
    end

    it "jump along the wall and go to left corner" do
      checking_proc = Proc.new{ |player, p_tick, params|
        next true if p_tick == 10
        check_player(player, {x: 0.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 3 #ударились головой
        check_player(player, {x: 0.5, y: 3.5, vx: 0, vy: 0}) if p_tick == 9 #упали
        false
      }
      dy_rule = Proc.new{|p_tick| p_tick == 0 ? -1 : 0}
      EM.run{ def_request( {sid: sid_a, send_limit: 10, dx_rule: -1, dy_rule: dy_rule, checking_proc: checking_proc} ) }
    end

    it "jump and fall" do
      EM.run do
        p_tick = 0
        request = web_socket_request(sid_a)
        curr_player = spawns[2]
        request.stream { |message, type|
          p_tick += 1
          arr = json_decode(message)
          player = arr['players'][0]
          should_eql(player['y'], curr_player[:coord].y, "coord.y")
          should_eql(player['vy'], curr_player[:velocity].y, "velocity.y")
          if p_tick == 1
            send_ws_request(request, "move", {sid: sid_a, dx: 0, dy: -1, tick: arr['tick']})
            curr_player[:coord].y += (curr_player[:velocity].y = -game_consts[:max_velocity])
            next
          end
          curr_player[:coord].y += (curr_player[:velocity].y += game_consts[:gravity])
          send_ws_request(request, "empty", {sid: sid_a, tick: arr['tick']})
          close_socket(request, sid_a) if p_tick == 22
        }
      end
    end

    it "go out the floor" do
      EM.run{ def_request( {sid: sid_a, check_limit: 10, send_limit: 10, x: 7.5, y: 1, vy: 0.2, dx_rule: 1} ) }
    end

    it "fall to narrow" do
      action = Proc.new{|p_tick| p_tick % 2 == 0 ? "move" : "empty"}
      EM.run{ def_request( {sid: sid_a, check_limit: 45, send_limit: 45, x: 1.5, y: 4.5, action: action, dx_rule: 1} ) }
    end

    it "jump to left corner" do
      dx_rule = Proc.new{|p_tick| p_tick < 4 ? -1 : 0}
      dy_rule = Proc.new{|p_tick| p_tick == 4 ? -1 : 0}
      EM.run{ def_request( {sid: sid_a, check_limit: 7, send_limit: 6, x: 6.5, y: 2.5, dx_rule: dx_rule, dy_rule: dy_rule} ) }
    end

    it "exception collison by left bottom corner" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if player["x"] > 4.5
        "move"
      }
      EM.run{ def_request( {sid: sid_a, check_limit: 40, send_limit: 40, vx: -0.1, x: 4.4, y: 0.5, action: action, dx_rule: -1} ) }
    end

    it "exception collison by right bottom corner" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if player["x"] < 1.5
        "move"
      }
      EM.run{ def_request( {sid: sid_a, check_limit: 40, send_limit: 40, vx: 0.1, x: 1.6, y: 3.5, action: action, dx_rule: 1} ) }
    end

    it "collision with right portion of the bottom edge of wall and then with top partion of the right edge of other wall" do
      dx_rule = Proc.new{ |p_tick| p_tick > 8 && p_tick < 17 ? 1 : -1}
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0}
      checking_proc = Proc.new{ |player, p_tick, params|
        next true if p_tick == 21
        if p_tick == 12 #ударились головой, пролетели влево
          player['x'].should < 4.5
          player['vx'].should < -0.2
          check_player(player, {y: 2.55, vy: 0.05})
        end
        check_player(player, {x: 3.5, y: 4.5, vx: 0, vy: 0}) if p_tick == 20  #ударились левым нижним углом, упали
        false
      }
      EM.run{ def_request( {sid: sid_a, send_limit: 21, dx_rule: dx_rule, dy_rule: dy_rule, checking_proc: checking_proc} ) }
    end

    it "try jump then run to right wall and fall" do
      dy_rule = Proc.new{ |p_tick| p_tick < 3 ? -1 : 0}
      checking_proc = Proc.new{ |player, p_tick, params|
        next true if p_tick == 22
        check_player(player, {y: 0.5, vy: 0}) if p_tick < 3 #бъемся в потолок
        check_player(player, {x: 7.5, y: 3.5, vx: 0, vy: 0}) if p_tick == 22  #ударились левым нижним углом, упали
        false
      }
      EM.run{ def_request( {sid: sid_a, send_limit: 22, dx_rule: 1, dy_rule: dy_rule, checking_proc: checking_proc} ) }
    end

    it "collision with a left top partion of wall's edge" do
      EM.run{ def_request( {sid: sid_a, send_limit: 20, check_limit: 20, x: 4.5, y: 4.5, dx_rule: 1} ) }
    end

    it "collision with a right top partion of wall's edge" do
      EM.run{ def_request( {sid: sid_a, send_limit: 20, check_limit: 20, x: 3.5, y: 4.5, dx_rule: -1} ) }
    end

    it "fall to narrow, right step, jump on tip of corner, left step" do
      action = Proc.new{ |p_tick| p_tick % 2 == 0 ? "move" : "empty" }
      dx_rule = Proc.new{ |p_tick| p_tick < 42 || p_tick == 56 ? -1 : p_tick == 48 ? 1 : 0 }
      dy_rule = Proc.new{ |p_tick| p_tick == 50 ? -1 : 0}
      checking_proc = Proc.new{ |player, p_tick, params|
        next true if p_tick == 66
        check_player(player, {x: 4.55, y: 3.5, vy: 0, vx: 0}) if p_tick == 50 #стоим на уголке
        check_player(player, {x: 4.55, y: 2.5, vx: 0, vy: 0}) if p_tick == 53 #ударились в верхний уголок
        check_player(player, {x: 4.5, y: 4.5, vy: 0, vx: 0}) if p_tick == 65 #упали на пол
        false
      }
      EM.run{
        def_request( {sid: sid_a, send_limit: 66, action: action, dx_rule: dx_rule, dy_rule: dy_rule, checking_proc: checking_proc} )
      }
    end

    it "collision with a left portion of the bottom edge of wall" do
      dx_rule = Proc.new{ |p_tick| p_tick == 9 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 9 ? -1 : 0}
      checking_proc = Proc.new{ |player, p_tick, params|
        next true if p_tick == 21
        check_player(player, {x: 4.2, y: 2.5, vy: 0, vx: 0.5}) if p_tick == 12 #ударились головой
        check_player(player, {x: 7.5, y: 3.5, vx: 0, vy: 0}) if p_tick == 20
        false
      }
      EM.run{
        def_request( {sid: sid_a, send_limit: 21, dx_rule: dx_rule, dy_rule: dy_rule, checking_proc: checking_proc} )
      }
    end

  end
end
