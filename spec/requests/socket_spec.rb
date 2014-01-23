require "spec_helper"

describe 'Socket server' do

  game_id = 0
  sid_a = sid_b = ""
  map = ""
  game_consts = {accel: 0.05, max_velocity: 0.5, gravity: 0.05, friction: 0.05}

  before(:all) do
    send_request(action: "startTesting", params: {websocketMode: "sync"})
    send_request(action: "signup", params: {login: "user_a", password: "password"})
    send_request(action: "signup", params: {login: "user_b", password: "password"})
    send_request(action: "signin", params: {login: "user_a", password: "password"})
    sid_a = json_decode(response.body)["sid"]
    send_request(action: "signin", params: {login: "user_b", password: "password"})
    sid_b = json_decode(response.body)["sid"]
    map = ['1.$.2',
           '#####',
           '..31.',
           '#####',
           '.3.#.',
           '#####',
           '#2..#']
    game_id = recreate_game(map, sid_a, sid_b, game_consts, 0)
  end

  before do
    @ws_requests = Array.new
    reconnect(sid_a, game_id)
    reconnect(sid_b, game_id)
  end

  def reconnect(sid, game_id)
    send_request(action: "leaveGame", params: {sid: sid})
    send_request(action: "joinGame", params: {sid: sid, game: game_id})
  end

  def recreate_game(map, sid_a, sid_b, game_consts, index)
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
    game_id
  end

  def check_player(got_player, expected_player)
    expected_player.map{|key, val|
      [:x, :y, :vx, :vy, :angel].include?(key) ? should_eql(got_player[key.to_s], val, key.to_s)
                                               : got_player[key.to_s].should == val
    }
  end

  def check_items(got_items, expected_items)
    expected_items.each_index{|i| should_eql(got_items[i], expected_items[i], "item #{i}")}
  end

  @requests_file

  def load_requests_file(name, spawn, mode = "w")
    name = name.gsub(/[\\\/+-]/, "")
    @requests_file = File.open("spec/requests_files/#{name}.txt", mode)
    @requests_file.puts("{\"x\": #{spawn.x}, \"y\": #{spawn.y}}")
  end

  def send_and_check (params)
    params_list = [:dx_rule, :dy_rule, :index, :x, :y, :vx, :vy, :check_limit, :send_limit, :name]
    params_list.each {|i| params[i] ||= 0 }
    params[:action] ||= "move"
    request = web_socket_request(params[:sid])
    p_tick = 0
    params[:checking] ||= Proc.new{ |player, p_tick, params|
      next false if p_tick != params[:check_limit]
      check_player(player, {x: params[:x], y: params[:y], vx: params[:vx], vy: params[:vy]})
      true
    }
    request.stream { |message, type|
      full_response = json_decode(message)
      tick = full_response['tick']
      player = full_response['players'][params[:index]]
      player = {"x" => player[0], "y" => player[1], "vx" => player[2], "vy" => player[3], "weapon" => player[4], "angel" => player[5],
                "login" => player[6], "hp" => player[7], "respawn" => player[8], "kills" => player[9], "deaths" => player[10]}
      if params.include?(:wait_items_resp) && full_response['items'].delete_if{|i| i.to_i == 0}.size != 0
        send_ws_request(request, "empty", {sid: params[:sid], dx: 0, dy: 0, tick: tick})
        next
      end
      puts "Sid = #{params[:sid][0..2]}, Cnt = #{p_tick}, Player = #{player}, Items = #{full_response['items']}," +
           " Tick = #{tick}" if params.include?(:log)
      close_socket(request, params[:sid]) if params[:checking].call(player, p_tick, params, full_response)
      dx = params[:dx_rule].kind_of?(Proc) ? params[:dx_rule].call(p_tick, player) : params[:dx_rule]
      dy = params[:dy_rule].kind_of?(Proc) ? params[:dy_rule].call(p_tick, player) : params[:dy_rule]
      action = params[:action].kind_of?(Proc) ? params[:action].call(p_tick, player) : params[:action]
      action = "empty" if p_tick >= params[:send_limit] && params[:send_limit] != 0
      send_ws_request(request, action, arr = {sid: params[:sid], dx: dx, dy: dy, tick: tick})
      @requests_file.puts(json_encode({action: action, params: arr})) if params.include?(:make_file)
      p_tick += 1
    }
  end

  describe "simple movings, spawn, collisions: " do

    spawns = [Point(2.5, 0.5)]

    it "players spawn" do
      def_params = [2.5, 0.5, 0.0, 0.0, "K", -1, 100, 0, 0, 0]
      checking_a = Proc.new{ |player, p_tick, params, request|
        send_and_check( {index: 1, sid: sid_b, checking: Proc.new{ true }} ) if p_tick == 0
        request["players"].should == [def_params.dup.insert(6, "user_a"),
                                      def_params.dup.insert(6, "user_b")] if p_tick == 19
        p_tick == 20
      }
      EM.run{ send_and_check( {sid: sid_a, checking: checking_a} ) }
    end

    it "+/- one step move" do
      dx_rule = Proc.new{ |p_tick| p_tick % 2 == 0 ? (p_tick % 4 == 0 ? 1 : -1) : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 2.55, y: 0.5, vx: 0.05, vy: 0}) if p_tick == 1
        check_player(player, {x: 2.55, y: 0.5, vx: 0, vy: 0}) if p_tick == 2
        check_player(player, {x: 2.5, y: 0.5, vx: -0.05, vy: 0}) if p_tick == 3
        p_tick == 4
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, checking: checking} ) }
    end

    it "inc/dec velocity" do
      curr_player = {coord: spawns[0].clone, velocity: Point(0, 0)}
      dx_rule = Proc.new{ |p_tick| p_tick > 4 ? 0 : 1 }
      checking = Proc.new{ |player, p_tick|
        next true if p_tick == 9
        check_player(player, {x: curr_player[:coord].x, y: 0.5, vx: curr_player[:velocity].x, vy: 0})
        curr_player[:coord].x += curr_player[:velocity].x += p_tick > 4 ? -game_consts[:friction] : game_consts[:accel]
        false
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, checking: checking} ) }
    end

    it "tick" do
      check_tick = -1
      checking = Proc.new{ |player, p_tick, params, request|
        should_eql(request['tick'], check_tick + 1,  "tick") if check_tick != -1
        check_tick = request['tick']
        p_tick == 10
      }
      EM.run {send_and_check( {sid: sid_a, checking: checking} ) }
    end

    it "stay at tp" do
      EM.run { send_and_check( {sid: sid_a, check_limit: 15, send_limit: 6, x: 1.65, y: 6.5, dx_rule: 1} ) }
    end

    it "one step to right tp" do
      action = Proc.new{ |p_tick| p_tick % 2 == 1 ? "empty" : "move"}
      EM.run { send_and_check( {sid: sid_a, action: action, check_limit: 62, x: 1.5, y: 6.5, dx_rule: 1} ) }
    end

    it "one step to left tp" do
      action = Proc.new{ |p_tick| p_tick % 2 == 1 ? "empty" : "move"}
      EM.run { send_and_check( {sid: sid_a, action: action, check_limit: 62, x: 3.5, y: 2.5, dx_rule: -1} ) }
    end

    it "to right wall" do
      EM.run { send_and_check( {sid: sid_a, check_limit: 20, x: 3.5, y: 6.5, dx_rule: 1} ) }
    end

    it "to left wall" do
      dx_rule = Proc.new{|p_tick| p_tick > 5 ? -1 : 1}
      EM.run { send_and_check( {sid: sid_a, check_limit: 15, x: 1.5, y: 6.5, dx_rule: dx_rule } ) }
    end

    it "left border" do
      EM.run { send_and_check( {sid: sid_a, check_limit: 20, send_limit: 10, x: 0.5, y: 4.5, dx_rule: -1} ) }
    end

    it "right border" do
      dx_rule = Proc.new{|p_tick| p_tick > 5 ? 1 : -1}
      EM.run { send_and_check( {sid: sid_a, check_limit: 20, x: 4.5, y: 2.5, dx_rule: dx_rule} ) }
    end

    it "two players run" do
      EM.run {
        dx_rule_a = Proc.new{|p_tick| p_tick > 15 ? 1 : -1}
        send_and_check( {sid: sid_a, check_limit: 40, x: 3.5, y: 6.5, dx_rule: dx_rule_a} )
        dx_rule_b = Proc.new{|p_tick| p_tick > 15 ? -1 : 1}
        send_and_check( {index: 1, sid: sid_b, check_limit: 40, x: 0.5, y: 4.5, dx_rule: dx_rule_b} )
      }
    end

    it "max velocity" do
      dx_rule = Proc.new{|p_tick| p_tick > 15 ? 1 : -1}
      EM.run {
        send_and_check( {sid: sid_a, check_limit: 30, x: 3.85, y: 0.5, vx: game_consts[:max_velocity], dx_rule: dx_rule} )
      }
    end
  end

  describe "Gravity: " do

    spawns = [Point(5.5, 0.5), Point(0.5, 3.5), Point(7.5, 3.5)]

    before(:all) do
      map = ['.....$..',
             '####.#..',
             '........',
             '$......$',
             '#.#..###']
      game_id = recreate_game(map, sid_a, sid_b, game_consts, 2)
    end

    it "respawns order" do
      f_player_spawn = spawns[0]
      s_player_spawn = spawns[1]
      checking_a = Proc.new{ |player, p_tick|
        check_player(player, {x: f_player_spawn.x, y: f_player_spawn.y})
        send_and_check( {index: 1, sid: sid_b, check_limit: 5, x: s_player_spawn.x, y: s_player_spawn.y} ) if p_tick == 10
        p_tick == 20
      }
      EM.run{ send_and_check( {sid: sid_a, checking: checking_a} ) }
      reconnect(sid_a, game_id)
      reconnect(sid_b, game_id)
      f_player_spawn = spawns[2]
      s_player_spawn = spawns[0]
      EM.run{ send_and_check( {sid: sid_a, checking: checking_a} ) }
    end

    #Spawn = 1
    it "jump along the wall and go to left corner" do
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 0.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 3 #ударились головой
        check_player(player, {x: 0.5, y: 3.5, vx: 0, vy: 0}) if p_tick == 9 #упали
        p_tick == 10
      }
      dy_rule = Proc.new{|p_tick| p_tick == 0 ? -1 : 0}
      EM.run{ send_and_check( {sid: sid_a, dx_rule: -1, dy_rule: dy_rule, checking: checking} ) }
    end

    #Spawn = 2
    it "jump and fall" do
      curr_player = {coord: spawns[2].clone, velocity: Point(0, 0)}
      dy_rule = Proc.new{ |p_tick| p_tick == 0 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {y: curr_player[:coord].y, vy: curr_player[:velocity].y})
        curr_player[:coord].y += (curr_player[:velocity].y = -game_consts[:max_velocity]) if p_tick == 0
        curr_player[:coord].y += (curr_player[:velocity].y += game_consts[:gravity]) if p_tick > 0
        p_tick == 20
      }
      EM.run{ send_and_check( {sid: sid_a, dy_rule: dy_rule, checking: checking} ) }
    end

    #Spawn = 0
    it "go out the floor" do
      EM.run{ send_and_check( {sid: sid_a, check_limit: 10, x: 7.5, y: 1, vy: 0.2, dx_rule: 1} ) }
    end
    #Spawn = 1
    it "fall to narrow" do
      action = Proc.new{|p_tick| p_tick % 2 == 0 ? "move" : "empty"}
      EM.run{ send_and_check( {sid: sid_a, check_limit: 45, x: 1.5, y: 4.5, action: action, dx_rule: 1} ) }
    end
    #Spawn = 2
    it "jump to left corner" do
      dx_rule = Proc.new{|p_tick| p_tick < 5 ? -1 : 0}
      dy_rule = Proc.new{|p_tick| p_tick == 2 ? -1 : 0}
      EM.run{ send_and_check( {sid: sid_a, check_limit: 26, x: 6.5, y: 3.5, dx_rule: dx_rule, dy_rule: dy_rule} ) }
    end
    #Spawn = 0
    it "exception collison by left bottom corner" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if player["x"].round(Settings.accuracy) > 4.5
        "move"
      }
      EM.run{ send_and_check( {sid: sid_a, check_limit: 40, vx: -0.1, x: 4.4, y: 0.5, action: action, dx_rule: -1} ) }
    end
    #Spawn = 1
    it "exception collison by right bottom corner" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if player["x"].round(Settings.accuracy) < 1.5
        "move"
      }
      EM.run{ send_and_check( {sid: sid_a, check_limit: 40, vx: 0.1, x: 1.6, y: 3.5, action: action, dx_rule: 1} ) }
    end
    #Spawn = 2
    it "collision with right portion of the bottom edge of wall and then with top portion of the right edge of other wall" do
      dx_rule = Proc.new{ |p_tick| p_tick > 7 && p_tick < 15 ? 1 : -1}
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        if p_tick == 12 #ударились головой, пролетели влево
          player['x'].round(Settings.accuracy).should < 5
          player['vx'].round(Settings.accuracy).should < -0.1
          check_player(player, {y: 2.55, vy: 0.05})
        end
        check_player(player, {x: 3.5, y: 4.5, vx: 0, vy: 0}) if p_tick == 20  #ударились левым нижним углом, упали
        p_tick == 21
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn = 0
    it "try jump then run to right wall and fall" do
      dy_rule = Proc.new{ |p_tick| p_tick < 3 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        check_player(player, {y: 0.5, vy: 0}) if p_tick < 3 #бъемся в потолок
        check_player(player, {x: 7.5, y: 3.5, vx: 0, vy: 0}) if p_tick == 22  #ударились левым нижним углом, упали
        p_tick == 22
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: 1, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn = 1
    it "collision with a left top partion of wall's edge" do
      EM.run{ send_and_check( {sid: sid_a, check_limit: 20, x: 4.5, y: 4.5, dx_rule: 1} ) }
    end
    #Spawn = 2
    it "collision with a right top partion of wall's edge" do
      EM.run{ send_and_check( {sid: sid_a, check_limit: 20, x: 3.5, y: 4.5, dx_rule: -1} ) }
    end
    #Spawn = 0
    it "fall to narrow, right step, jump on tip of corner, left step" do
      action = Proc.new{ |p_tick| p_tick % 2 == 0 ? "move" : "empty" }
      dx_rule = Proc.new{ |p_tick| p_tick < 42 || p_tick == 56 ? -1 : p_tick == 48 ? 1 : 0 }
      dy_rule = Proc.new{ |p_tick| p_tick == 50 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 4.55, y: 3.5, vy: 0, vx: 0}) if p_tick == 50 #стоим на уголке
        check_player(player, {x: 4.55, y: 2.5, vy: 0, vx: 0}) if p_tick == 53 #ударились в верхний уголок
        check_player(player, {x: 4.5, y: 4.5, vy: 0, vx: 0}) if p_tick == 65 #упали на пол
        p_tick == 66
      }
      EM.run{
        send_and_check( {sid: sid_a, action: action, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} )
      }
    end
    #Spawn = 1
    it "collision with a left portion of the bottom edge of wall" do
      dx_rule = Proc.new{ |p_tick| p_tick == 9 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 9 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 4.1, y: 2.5, vy: 0, vx: 0.5}) if p_tick == 12 #ударились головой
        check_player(player, {x: 7.5, y: 3.5, vy: 0, vx: 0}) if p_tick == 20
        p_tick == 21
      }
      EM.run{
        send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} )
      }
    end
    #Spawn = 2
    it "collision with a right edge of wall, fall, left step, jump" do
      action = Proc.new{ |p_tick| p_tick > 22 && p_tick < 25 ? "empty" : "move"}
      dx_rule = Proc.new{ |p_tick| p_tick == 3 || p_tick > 22 ? 0 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 3 || p_tick == 25 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 6.5, y: 1.5, vx: 0, vy: -0.3}) if p_tick == 8 #ударились об правое ребро стены
        check_player(player, {x: 6.45, y: 2.5, vx: 0, vy: 0}) if p_tick == 28  #ударились головой
        p_tick == 29
      }
      EM.run{
        send_and_check( {sid: sid_a, action: action, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} )
      }
    end

    it "save coords after WS disconnect" do
      (0..4).each{
        EM.run{ send_and_check( {sid: sid_a, x: spawns[0].x, y: spawns[0].y, check_limit: 10} ) }
      }
    end
  end

  describe "Flying close to the wall: " do

    spawns = [Point(0.5, 0.5), Point(9.5, 0.5)]

    before(:all) do
      map = ['......#......',
             '.............',
             '$...........$']
      game_id = recreate_game(map, sid_a, sid_b, {accel: 0.05, friction: 0.05, max_velocity: 0.7, gravity: 0.05}, 3)
    end
    #spawn 0
    it "from left to right" do
      dx_rule = Proc.new{ |p_tick| [8, 10, 13].include?(p_tick) || p_tick > 17 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 18 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 7.8, y: 1.15, vx: 0.5, vy: -0.65}) if p_tick == 20
        p_tick == 20
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end

    #spawn 1
    it "from right to left" do
      dx_rule = Proc.new{ |p_tick| [8, 10, 13].include?(p_tick) || p_tick > 17 ? 0 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 18 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 5.2, y: 1.15, vx: -0.5, vy: -0.65}) if p_tick == 20
        p_tick == 20
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
  end

  describe "TP, items with gravity: " do

    spawns = [Point(2.5, 4.5)]

    before(:all) do
      map = ['12.4....',
             '.......3',
             '....12..',
             '.......4',
             '3.$.....']
      game_id = recreate_game(map, sid_a, sid_b, game_consts, 4)
    end

    it "Multy tp" do
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 7.5, y: 1.5, vx: -0.4, vy: 0}) if p_tick == 8
        check_player(player, {x: 1.5, y: 0.5, vx: -0.5, vy: 0.25}) if p_tick == 13
        check_player(player, {x: 4.5, y: 2.5, vx: -0.5, vy: 0.35}) if p_tick == 15
        check_player(player, {x: 2.0, y: 4.5, vx: -0.5, vy: 0}) if p_tick == 20 #Облетели все тп
        p_tick == 21
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: -1, checking: checking} ) }
    end

    it "No tp by border intersect" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if p_tick < 60
        "empty"
      }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 1.0, y: 4.5, vx: 0, vy: 0}) if p_tick == 65 #касаемся границы телепорта
        p_tick == 66
      }
      EM.run{ send_and_check( {sid: sid_a, action: action, dx_rule: -1, checking: checking} ) }
    end

    it "Jump and fall to tp" do
      action = Proc.new{ |p_tick, player|
        next p_tick < 6 || p_tick == 12  ? "move" : "empty"
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 12 ? -1 : 0}
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 0.5, y: 0.5, vx: 0, vy: -0.35}) if p_tick == 16
        check_player(player, {x: 7.5, y: 1.5, vx: 0, vy: 0.5}) if p_tick == 29
        p_tick == 30
      }
      EM.run{ send_and_check( {sid: sid_a, action: action, dx_rule: 1, dy_rule: dy_rule, checking: checking} ) }
    end

    it "Use left near tp during jump" do
      dx_rule = Proc.new{ |p_tick|
        next 0 if p_tick == 7
        p_tick < 7 || p_tick == 10 ? 1 : -1
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 7 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 0.5, y: 0.5, vy: -0.35}) if p_tick == 11
        p_tick == 12
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end

    it "Use right near tp during jump" do
      dx_rule = Proc.new{ |p_tick|
        next 1 if p_tick < 20
        next 0 if p_tick == 27
        p_tick < 27 || p_tick == 30 ? -1 : 1
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 27 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 1.5, y: 0.5, vx: -0.25, vy: -0.35}) if p_tick == 31
        p_tick == 32
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end

    it "Flying close" do
      action = Proc.new{ |p_tick, player|
        next p_tick % 2 == 0 ? "move" : "empty" if p_tick < 40
        "move"
      }
      dx_rule = Proc.new{ |p_tick| p_tick == 48 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 48 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 6.5, y: 3.15, vx: 0.45, vy: -0.4}) if p_tick == 51
        p_tick == 52
      }
      #load_requests_file(example.description, spawns[0])
      EM.run{ send_and_check( {sid: sid_a, action: action, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
  end

  describe "Inside unusual block: " do

    spawns = [Point(1.5, 2.5), Point(7.5, 2.5), Point(11.5, 3.5)]

    before(:all) do
      map = ['.#######......',
             '#.......#..#..',
             '#$.....$#.....',
             '.#######..#$#.']
      game_id = recreate_game(map, sid_a, sid_b, game_consts, 5)
    end
    #Spawn 0
    it "jump, fall, run to right corner" do
      dx_rule = Proc.new{ |p_tick| p_tick < 9 ? -1 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 0 || p_tick == 24 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 1.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 9 #упали на место, после прыжка
        check_player(player, {x: 7.5, y: 1.5, vx: 0, vy: 0}) if p_tick == 27 #врезались в правый верхний угол блока
        check_player(player, {x: 7.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 33 #упали вниз
        p_tick == 34
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn 1
    it "jump, fall, run to left corner" do
      dx_rule = Proc.new{ |p_tick| p_tick < 9 ? 1 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 0 || p_tick == 24 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 7.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 9 #упали на место, после прыжка
        check_player(player, {x: 1.5, y: 1.5, vx: 0, vy: 0}) if p_tick == 27 #врезались в левый верхний угол блока
        check_player(player, {x: 1.5, y: 2.5, vx: 0, vy: 0}) if p_tick == 33 #упали вниз
        p_tick == 34
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn 2
    it "run from trap to the left and go right" do
      dx_rule = Proc.new{ |p_tick| p_tick < 6 ? -1 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 0 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 11.2, y: 2.5, vx: -0.15, vy: 0}) if p_tick == 6 #залезли на стену
        check_player(player, {x: 11.8, y: 2.5, vx: 0.25, vy: 0}) if p_tick == 14 #пробежали яму вправо
        p_tick == 15
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn 0
    it "jump at the junction between walls from the left" do
      dx_rule = Proc.new{ |p_tick|
        next 0 if p_tick == 6
        next -1 if p_tick == 8
        1
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 6 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 3.65, y: 1.55, vx: 0.3, vy: 0.05}) if p_tick == 10 #не зацепились за левый стык
        p_tick == 11
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn 1
    it "jump at the junction between walls from the right" do
      dx_rule = Proc.new{ |p_tick|
        next 0 if p_tick == 6
        next 1 if p_tick == 8
        -1
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 6 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 5.35, y: 1.55, vx: -0.3, vy: 0.05}) if p_tick == 10 #не зацепились за правый стык
        p_tick == 11
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #Spawn 2
    it "run from trap to the right and go left" do
      dx_rule = Proc.new{ |p_tick| p_tick < 6 ? 1 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 0 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 11.8, y: 2.5, vx: 0.15, vy: 0}) if p_tick == 6 #залезли на стену
        check_player(player, {x: 11.2, y: 2.5, vx: -0.25, vy: 0}) if p_tick == 14 #пробежали яму влево
        p_tick == 15
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
  end

  describe "Order of tp/cell: " do

    spawns = [Point(0.5, 1.5), Point(8.5, 1.5), Point(13.5, 3.5), Point(17.5, 3.5)]

    before(:all) do
      map = ['....1.......#...........',
             '$.......$.1.#3...2#.2..3',
             '#############.....#.....',
             '............#$...$#.....']
      game_id = recreate_game(map, sid_a, sid_b, {accel: 0.08, friction: 0.08, max_velocity: 0.8, gravity: 0.08}, 6)
    end
    #spawn 0
    it "run right, jump, vertical collision before tp" do
      dx_rule = Proc.new{ |p_tick| p_tick == 7 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 7 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 11.22, y: 1.5, vx: 0.72, vy: 0}) if p_tick == 11
        p_tick == 11
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 1
    it "run left, jump,vertical collision before tp" do
      dx_rule = Proc.new{ |p_tick| p_tick == 7 ? 0 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 7 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 9.78, y: 1.5, vx: -0.72, vy: 0}) if p_tick == 11
        p_tick == 11
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 2
    it "run right, jump, horizontal collision before tp" do
      dx_rule = Proc.new{ |p_tick| p_tick == 8 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 20.5, y: 1.5, vx: 0, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 3
    it "run left, jump, horizontal collision before tp" do
      dx_rule = Proc.new{ |p_tick| p_tick == 8 ? 0 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 23.5, y: 1.5, vx: 0, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 0
    it "run right, jump, tp before vertical collision" do
      dx_rule = Proc.new{ |p_tick| p_tick == 8 ? 0 : 1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 10.5, y: 1.5, vx: 0.64, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 1
    it "run left, jump, tp before vertical collision" do
      dx_rule = Proc.new{ |p_tick| p_tick == 8 ? 0 : -1 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 10.5, y: 1.5, vx: -0.64, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 2
    it "run right, jump, tp before horizontal collision" do
      dx_rule = Proc.new{ |p_tick| p_tick < 8 ? 1 : 0 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 20.5, y: 1.5, vx: 0.48, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
    #spawn 3
    it "run left, jump, tp before horizontal collision" do
      dx_rule = Proc.new{ |p_tick| p_tick < 8 ? -1 : 0 }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 23.5, y: 1.5, vx: -0.48, vy: -0.72}) if p_tick == 10
        p_tick == 10
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} ) }
    end
  end

  describe "Some critical test: " do

    spawns = [Point(29.5, 0.5)]

    before(:all) do
      map = ['1............................$1']
      game_id = recreate_game(map, sid_a, sid_b, {accel: 0.05, friction: 0.05, max_velocity: 0.5, gravity: 0.05}, 7)
    end

    it "eps error" do
      dx_rule = Proc.new{ |p_tick| p_tick % 2 == 0 ? 1 : 0 }
      checking = Proc.new{ |player, p_tick|
        check_player(player, {x: 0.5, y: 0.5}) if p_tick == 21
        p_tick == 21
      }
      EM.run{ send_and_check( {sid: sid_a, dx_rule: dx_rule, checking: checking} ) }
    end
  end

  describe "Items, fire: " do

    spawns = [Point(12.5, 0.5), Point(1.5, 2.5)]

    before(:all) do
      map = ['.h...........',
             '.h..P.......#',
             'M$..R..A...P#']
      game_id = recreate_game(map, sid_a, sid_b, {accel: 0.05, friction: 0.05, max_velocity: 0.5, gravity: 0.05}, 8)
    end

    #spawn 0, 1
    it "pick up some stuff" do
      dx_rule = Proc.new{ |p_tick| p_tick > 3 ? -1 : 0 }
      dy_rule = Proc.new{ |p_tick| p_tick == 0 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick, params, full_request|
        items = full_request["items"]
        should_be_true(items[1] > 0, "item 1 > 0") if p_tick == 2
        should_be_true(items[0] > 0, "item 0 > 0") if p_tick == 4
        if p_tick == 14
          should_be_true(items[3] > 0, "item 3 > 0")
          check_player(player, {weapon: "M"})
        end
        p_tick == 14
      }
      EM.run{
        send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} )
      }
    end

    #spawn 0, 1
    it "pick up some stuff 2" do
      dx_rule = Proc.new{ |p_tick|
        next 0 if p_tick == 8
        p_tick < 13 ? 1 : 0
      }
      dy_rule = Proc.new{ |p_tick| p_tick == 8 ? -1 : 0 }
      checking = Proc.new{ |player, p_tick, params, full_request|
        items = full_request["items"]
        if p_tick == 10
          should_be_true(items[2] > 0, "item #2 > 0")
          check_player(player, {weapon: "P"})
        end
        if p_tick == 24
          should_be_true(items[5] > 0, "item #5 > 0")
          check_player(player, {weapon: "A"})
        end
        p_tick == 24
      }
      EM.run{
        send_and_check( {sid: sid_a, dx_rule: dx_rule, dy_rule: dy_rule, checking: checking} )
      }
    end

    #spawn 0, 1
    it "projectiles collisions" do
      dx_rule = Proc.new{ |p_tick|
        next -1 if p_tick < 6 || p_tick == 22  #идем влево
        next 3 if p_tick == 7
        next 1 if p_tick == 8
        0
      }
      dy_rule = Proc.new{ |p_tick|
        next -1 if p_tick == 6
        next -2 if p_tick == 7
        next 1 if p_tick == 20
        0
      }
      action = Proc.new{ |p_tick|
        next "move" if p_tick < 6
        next "fire" if [6, 7, 8, 20, 22].include?(p_tick)
        "empty"
      }
      checking = Proc.new{ |player, p_tick, params, full_request|
        prjs = full_request["projectiles"]
        prjs.size.should == 0 if p_tick == 1
        prjs.size.should == 1 if [7, 21, 23].include?(p_tick)
        prjs.size.should == 2 if [8, 11].include?(p_tick)
        p_tick == 23
      }
      EM.run{
        send_and_check( {wait_items_resp: 1, sid: sid_a, log:1, dx_rule: dx_rule, dy_rule: dy_rule, action: action, checking: checking} )
      }
    end
  end

  after(:all) do
    send_request(action: "leaveGame", params: {sid: sid_a})
    send_request(action: "leaveGame", params: {sid: sid_b})
  end
end
