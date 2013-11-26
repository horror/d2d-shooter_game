//= require jquery

const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81;
var keys_to_params = {
        38: {"action": "move", "params": {"dx": 0, "dy": -1}},
        40: {"action": "move", "params": {"dx": 0, "dy": 1}},
        37: {"action": "move", "params": {"dx": -1, "dy": 0}},
        39: {"action": "move", "params": {"dx": 1, "dy": 0}},
        81: {"action": "empty", "params": {}}
    },
    hostname = window.location.hostname.replace('www.',''), port = window.location.port,
    web_socket_url = 'ws://' + hostname + ':8001', server_url = 'http://' + hostname + ':' + port, tick = 0,
    stage, curr_shape, web_socket,
    SCALE = 30;


function start_websocket(sid)
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
            curr_shape.graphics.drawRect(players[i]["x"] * SCALE - 0.5 * SCALE, players[i]["y"] * SCALE - 0.5 * SCALE, SCALE, SCALE);
        stage.addChild(curr_shape);
        stage.update();
       // console.log('onmessage, ' + event.data);
    };

    web_socket.onclose = function(event) {
        console.log('onclose');
    };
};

function draw_map(map)
{
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

var pressed_keys = {38: false, 37: false, 39: false, 40: false, 81: false}
var pressed = false;

function key_hold(sid)
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

