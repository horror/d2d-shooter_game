//= require jquery

var sid = "", web_socket_url = 'ws://localhost:8001', server_url = 'http://localhost:3000', tick = 0,
    maps = "", stage, newPlayers, web_socket;
var SCALE = 20, users_list = ["user_a", "user_b"];

newPlayers = new createjs.Shape();
newPlayers.graphics.beginStroke("red")

function send_request(action, params, call_back_func)
{
    var http_request = new XMLHttpRequest();
    http_request.open('POST', server_url, true);
    http_request.setRequestHeader('Content-Type', 'application/json; charset=utf-8');
    http_request.send(JSON.stringify({"action": action, "params": params}));
    http_request.onreadystatechange = function() {
        if (!call_back_func)
            return
        if (http_request.readyState == 4 && http_request.status == 200)
            call_back_func(JSON.parse(http_request.responseText), params)
    };
}

function init()
{
    var sid_a, sid_b, map = ['1.$.2', '#####', '..31.', '#####', '.3.#.', '#####', '#2..#'];

    getGames_callback = function(request, params) {
        send_request("joinGame", {"sid": sid_b, "game": request["games"][0]["id"]});
    }

    createGame_callback = function(request, params) { send_request("getGames", {"sid": sid_a}, getGames_callback) }

    getMaps_callback = function(request, params) {
        send_request("createGame", {sid: sid_a, name: "New game", "map": request["maps"][0]["id"], maxPlayers: 10}, createGame_callback);
    }

    uploadMap_callback = function(request, params) { send_request("getMaps", {sid: sid_a}, getMaps_callback) }

    a_signin_callback = function(request, params) {
        sid_a = request['sid'];
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
    web_socket = new WebSocket(web_socket_url);

    web_socket.onopen = function(event) {
        console.log('onopen');
        web_socket.send(JSON.stringify({"action": "move", "params": {"sid": sid, "dx": 0, "dy": 0}}));
    };

    web_socket.onmessage = function(event) {
        tick = JSON.parse(event.data)['tick'];
        players = JSON.parse(event.data)['players'];
        stage.removeChild(newPlayers);
        newPlayers = new createjs.Shape();
        newPlayers.graphics.beginStroke("red");
        for (var i = 0; i < players.length; ++i)
            newPlayers.graphics.drawRect(players[i]["x"] * SCALE - 0.5 * SCALE, players[i]["y"] * SCALE - 0.5 * SCALE, SCALE, SCALE);
        stage.addChild(newPlayers);
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
                rect.graphics.beginFill("blue").drawCircle(i * SCALE + 0.5 * SCALE, j * SCALE + 0.5 * SCALE, SCALE / 5);
            if (!isNaN(parseInt(map[j][i], 10)))
                rect.graphics.beginFill("green").drawCircle(i * SCALE + 0.5 * SCALE, j * SCALE + 0.5 * SCALE, SCALE / 5);
        }
    stage.addChild(rect);
    stage.update();
}

var pressed = false

function left_hold()
{
    web_socket.send(JSON.stringify({"action": "move", "params": {"sid": sid, "dx": -1, "dy": 0, "tick": tick}}))
    if (pressed)
        setTimeout('left_hold()', 60);
}

function right_hold()
{
    web_socket.send(JSON.stringify({"action": "move", "params": {"sid": sid, "dx": 1, "dy": 0, "tick": tick}}))
    if (pressed)
        setTimeout('right_hold()', 60);
}

$(document).ready( function () {
    for (var i = 0; i < users_list.length; ++i)
        $("select, #users").append(
            $("<\option>", {"text": users_list[i], "name": users_list[i]})
        );
})
