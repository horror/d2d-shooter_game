//= require jquery

const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81,
      SCALE = 30, PLAYER_HALFRECT = 0.5;
var keys_to_params = {
        38: {"action": "move", "params": {"dx": 0, "dy": -1}},
        40: {"action": "move", "params": {"dx": 0, "dy": 1}},
        37: {"action": "move", "params": {"dx": -1, "dy": 0}},
        39: {"action": "move", "params": {"dx": 1, "dy": 0}},
        81: {"action": "empty", "params": {}}
    },
    hostname = window.location.hostname.replace('www.',''), port = window.location.port,
    sid = "", web_socket_url = 'ws://' + hostname + ':8001', server_url = 'http://' + hostname + ':' + port, tick = 0,
    maps = "", stage, curr_shape, web_socket,
    users_list = ["user_a", "user_b"];

function send_request(action, params, call_back_func)
{
    $.ajax({
        type: "POST",
        url: server_url,
        data: JSON.stringify({"action": action, "params": params}),
        success: function(data) {
            if (!call_back_func)
                return
            call_back_func(data, params)
        },
        dataType: "json",
        contentType: "application/json; charset=utf-8"
    });
}

function init()
{
    var sid_a, sid_b, map = $('#init_map').val();
    map = map == "" ? ['1.$.2', '#####', '..31.', '#####', '.3.#.', '#####', '#2..#'] : map.split("\n");

    getGames_callback = function(request, params) {
        send_request("joinGame", {"sid": sid_b, "game": request["games"][0]["id"]});
    }

    createGame_callback = function(request, params) { send_request("getGames", {"sid": sid_a}, getGames_callback) }

    getMaps_callback = function(request, params) {
        send_request("createGame", {sid: sid_a, name: "New game", "map": request["maps"][0]["id"], maxPlayers: 10}, createGame_callback);
    }

    uploadMap_callback = function(request, params) { send_request("getMaps", {sid: sid_a}, getMaps_callback) }

    a_signin_callback = function(request, params) {
        sid = sid_a = request['sid'];
        send_request("uploadMap", {sid: sid_a, name: "New map", maxPlayers: 10, map: map}, uploadMap_callback)
    }

    b_signin_callback = function(request, params) { sid_b = request['sid']; }

    a_signup_callback = function(request, params) {
        send_request("signin", {login: "user_a", password: "password"}, a_signin_callback)
    }
    b_signup_callback = function(request, params) {
        send_request("signin", {login: "user_b", password: "password"}, b_signin_callback)
    }
    st_callback = function(request, params) {
        send_request("signup", {login: "user_a", password: "password"}, a_signup_callback);
        send_request("signup", {login: "user_b", password: "password"}, b_signup_callback);
    }
    send_request("startTesting", {"websocketMode": "async"}, st_callback);
}

function signin()
{
    f = function (response, params) {
        sid = response['sid'];
        get_map();
    }
    send_request("signin", {"login": $("select, #users").val(), "password": "password"}, f)
    $("#user_name").text($("select, #users").val());
}

function get_map()
{
    f = function (response, params) {
        maps = response['maps'];
        draw_map();
    }
    send_request("getMaps", {"sid": sid}, f)
}

function start_websocket()
{
    if (web_socket)
        web_socket.close();
    web_socket = new WebSocket(web_socket_url);

    web_socket.onopen = function(event) {
        console.log('onopen');
        web_socket.send(JSON.stringify({"action": "move", "params": {"sid": sid, "dx": 0, "dy": 0}}));
    };

    web_socket.onmessage = function(event) {
        tick = JSON.parse(event.data)['tick'];
        players = JSON.parse(event.data)['players'];
        stage.removeChild(curr_shape);
        curr_shape = new createjs.Shape();
        curr_shape.graphics.beginStroke("red");
        for (var i = 0; i < players.length; ++i)
            curr_shape.graphics.drawRect(players[i]["x"] * SCALE - PLAYER_HALFRECT * SCALE,
                                         players[i]["y"] * SCALE - PLAYER_HALFRECT * SCALE,
                                         SCALE * PLAYER_HALFRECT * 2, SCALE * PLAYER_HALFRECT * 2);
        stage.addChild(curr_shape);
        stage.update();
        console.log('onmessage, ' + event.data);
    };

    web_socket.onclose = function(event) {
        console.log('onclose');
    };
};

function draw_map()
{
    map = maps[0]['map'];
    stage = new createjs.Stage($("#main_canvas")[0]);
    rect = new createjs.Shape();
    rect.graphics.beginStroke("black").drawRect(0, 0, map[0].length * SCALE, map.length * SCALE).endStroke();
    stage.addChild(rect);
    for (var j = 0; j < map.length; ++j)
        for (var i = 0; i < map[0].length; ++i)
        {
            if (map[j][i] == "#")
                rect.graphics.beginFill("blue").drawRect(i * SCALE, j * SCALE, SCALE, SCALE);
            if (map[j][i] == "$")
                rect.graphics.beginFill("blue").drawCircle(i * SCALE + PLAYER_HALFRECT * SCALE, j * SCALE + PLAYER_HALFRECT * SCALE, SCALE / 5);
            if (!isNaN(parseInt(map[j][i], 10)))
                rect.graphics.beginFill("green").drawCircle(i * SCALE + PLAYER_HALFRECT * SCALE, j * SCALE + PLAYER_HALFRECT * SCALE, SCALE / 5);
        }
    stage.addChild(rect);
    stage.update();
}

var pressed_keys = {38: false, 37: false, 39: false, 40: false, 81: false}
var pressed = false;

function key_hold()
{
    for (i in pressed_keys)
        if (pressed_keys[i])
        {
            pressed = true;
            var arr = keys_to_params[i];
            arr["params"]["sid"] = sid;
            arr["params"]["tick"] = tick;
            web_socket.send(JSON.stringify(arr));
        }
    if (pressed)
        setTimeout('key_hold()', 50);
}

$(document).ready( function () {
    for (var i = 0; i < users_list.length; ++i)
        $("select, #users").append(
            $("<\option>", {"text": users_list[i], "name": users_list[i]})
        );
    document.onkeydown = function(event) {
        if (!(event.keyCode in pressed_keys))
            return
        pressed_keys[event.keyCode] = true
        if (!pressed)
            key_hold()
    }
    document.onkeyup = function(event) {
        if (!(event.keyCode in pressed_keys))
            return
        pressed = pressed_keys[event.keyCode] = false
        for (i in pressed_keys)
            pressed = pressed || pressed_keys[i]
    }
})
