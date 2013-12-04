
const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81, KEY_MOUSE = "m",
    SCALE = 30, PLAYER_HALFRECT = 0.5, DEAD = "dead", SPRITE_SCALE = 0.9, SPRITE_SHIFT_X = 0.45, SPRITE_SHIFT_Y = 0.8;
var keys_to_params = {
        "m": {"action": "fire", params: {}},
        38: {"action": "move", "params": {"dx": 0, "dy": -1}},
        40: {"action": "move", "params": {"dx": 0, "dy": 1}},
        37: {"action": "move", "params": {"dx": -1, "dy": 0}},
        39: {"action": "move", "params": {"dx": 1, "dy": 0}},
        81: {"action": "empty", "params": {}}
    },
    hostname = window.location.hostname.replace('www.',''), port = window.location.port,
    web_socket_url = 'ws://' + hostname + ':8001', server_url = 'http://' + hostname + ':' + port, tick = 0,
    stage, container, web_socket, player_x = 0, player_y = 0,
    mouse_x, mouse_y, sprites = {};

var ss = new createjs.SpriteSheet({
    animations: {
        run_left: [0, 4],
        run_right: [5, 9],
        jump_left: [12],
        jump_right: [10],
    },
    images:["assets/img/walkcyclex.png"],
    frames:{
        height: 64,
        width: 64,
    },
});

function start_websocket(sid, login)
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
        var players = JSON.parse(event.data)['players'];
        var projectiles = JSON.parse(event.data)['projectiles'];
        stage.removeChild(container);
        var moving_objects = new createjs.Shape();
        container = new createjs.Container();
        container.addChild(moving_objects);
        moving_objects.graphics.beginStroke("red");
        for (var i = 0; i < players.length; ++i) {
            var player = players[i];

            if (player["status"] == DEAD)
                continue;

            if (player["login"] == login) {
                player_x = player["x"];
                player_y = player["y"];
            }

            //НИК
            var login_text = new createjs.Text(player["login"], "12px Arial", "blue");
            login_text.textBaseline = "alphabetic";
            login_text.x = (player["x"] - PLAYER_HALFRECT) * SCALE;
            login_text.y = (player["y"] - PLAYER_HALFRECT - 0.2) * SCALE;
            container.addChild(login_text);
            //ХП
            moving_objects.graphics.beginFill("#FFFFFF").drawRect(player["x"] * SCALE - PLAYER_HALFRECT * SCALE,
                player["y"] * SCALE - PLAYER_HALFRECT * SCALE * 2,
                SCALE * PLAYER_HALFRECT * 2, 0.3 * SCALE);
            moving_objects.graphics.beginFill("red").drawRect(player["x"] * SCALE - PLAYER_HALFRECT * SCALE,
                player["y"] * SCALE - PLAYER_HALFRECT * SCALE * 2,
                SCALE * PLAYER_HALFRECT * 2 * player["hp"] / 100, 0.3 * SCALE);
            //ИГРОК
            if (sprites[player["login"]] == undefined) {
                sprites[player["login"]] = new createjs.Sprite(ss);
                sprites[player["login"]].scaleY = sprites[player["login"]].scaleX = SPRITE_SCALE;
            }

            var sprite = sprites[player["login"]];
            var curr_animation = ((player["vy"] != 0) ? "jump_" : "run_") + ((player["vx"] > 0) ? "right" : "left");
            if (player["vx"] == 0)
                sprite.stop();
            else if (curr_animation != sprite.currentAnimation || sprite.paused)
                sprite.gotoAndPlay(curr_animation);
            container.addChild(sprite)
                .set({graphics: moving_objects, x: (player["x"] - SPRITE_SHIFT_X) * SCALE - PLAYER_HALFRECT * SCALE , y: (player["y"] - SPRITE_SHIFT_Y) * SCALE - PLAYER_HALFRECT * SCALE});
        }

        for (var i = 0; i < projectiles.length; ++i) {
            var projectile = projectiles[i];
            console.log(projectile);
            moving_objects.graphics.beginFill("red").drawCircle(projectile["x"] * SCALE ,
                projectile["y"] * SCALE, SCALE / 10);
        }
        stage.addChild(container);
        stage.update();
       // console.log('onmessage, ' + event.data);
    };

    web_socket.onclose = function(event) {
        console.log('onclose');
    };
};

function draw_map(map)
{
    $("#main_canvas").attr("width", map[0].length * SCALE);
    $("#main_canvas").attr("height", map.length * SCALE);
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

var pressed_keys = {38: false, 37: false, 39: false, 40: false, 81: false, "m": false}
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
            if (i == KEY_MOUSE)
            {
                arr["params"]["dx"] = mouse_x - player_x * SCALE,
                    arr["params"]["dy"] = mouse_y - player_y * SCALE;
            }
            web_socket.send(JSON.stringify(arr));
        }
    if (pressed)
        setTimeout("key_hold('" + sid + "')", 50);
}
