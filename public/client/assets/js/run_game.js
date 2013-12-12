
const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81, KEY_MOUSE = "m",
    SCALE = 30, PLAYER_HALFRECT = 0.5, DEAD = "dead",
    NICK_SHIFT_Y = 0.5, HP_BAR_SHIFT_Y = 0.34,
    PLAYER_SCALE_X = 0.9, PLAYER_SCALE_Y = 0.8, PLAYER_SHIFT_X = 0.45, PLAYER_SHIFT_Y = 0.45,
    MAP_PIECE_SCALE = 0.5, TELEPORT_SCALE_X = 0.2, TELEPORT_SCALE_Y = 0.2, TELEPORT_SHIFT_Y = 0.8, TELEPORT_SHIFT_X = 0.8;
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
    mouse_x, mouse_y, p_sprites = {}, wrapper_scroll_x = wrapper_scroll_y = 0, map_items = [];

var ss_items = new createjs.SpriteSheet({
    animations: {
        empty: 0,
        h: 1,
        G: 2,
    },
    images: ["assets/img/gameXYZqsbhd.png"],
    frames: [
        [0, 0, 1, 1],
        [325, 72, 54, 48],
        [73, 128, 108, 66],
    ],
});

function get_item (name) {
    var item = new createjs.Sprite(ss_items);
    item.scaleY = item.scaleX = MAP_PIECE_SCALE;
    item.gotoAndStop(name);
    return item;
}



var ss_telepot = new createjs.SpriteSheet({
    animations: {
        show: {
            frames: [0, 1, 2, 3, 4, 5],
            speed: 0.8,
        }
    },
    images: ["assets/img/teleport.png"],
    frames: {
        height: 512,
        width: 512,
    },
});

var ss_player = new createjs.SpriteSheet({
    animations: {
        run_left: [0, 4],
        run_right: [5, 9],
        jump_left: [12],
        jump_right: [10],
    },
    images: ["assets/img/walkcyclex.png"],
    frames: {
        height: 64,
        width: 64,
    },
});

var ss_map = new createjs.SpriteSheet({
    images: ["assets/img/grass_main.png"],
    frames: {
        height: 64,
        width: 64,
    }
});

var map_pieces_consitions = {
    //bottom
    "xxx11x0x" : 52,
    "xxx01x0x" : 36,
    "xxx10x0x" : 37,
    //top
    "00011xxx" : 16,
    "00001xxx" : 4,
    "00010xxx" : 5,
    "10011xxx" : 39,
    "00111xxx" : 23,
    //inner corners
    "x1011x1x" : 55,
    "01x11x1x" : 56,
    //sides
    "x1x01x1x" : 20,
    "x1x10x1x" : 21,
};

function get_map_piece (piece_id) {
    var piece = new createjs.Sprite(ss_map);
    piece.scaleY = piece.scaleX = MAP_PIECE_SCALE;
    piece.gotoAndStop(piece_id);
    return piece;
}

function compere_mask_with_condition(mask, condition) {
    var intersects = true;
    for (var i = 0; i < mask.length; ++i) {
        if (mask[i] != condition[i] && mask[i] != 'x')
            intersects = false;
    }

    return intersects;
}

function get_map_wall_piece(condition) {
    var condition = $.map(condition, function(item) { return item == "#"});
    var piece_id_need = 1;
    $.each(map_pieces_consitions, function (mask, piece_id) {
        if (compere_mask_with_condition(mask, condition))
            piece_id_need = piece_id;
    });

    return get_map_piece(piece_id_need);
}

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
        var data = JSON.parse(event.data);
        tick = data['tick'];
        var players = data['players'];
        var projectiles = data['projectiles'];
        var items = data['items'];
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
            var login_text = new createjs.Text(player["login"], "12px Arial", "black");
            login_text.textBaseline = "alphabetic";
            login_text.x = (player["x"] - PLAYER_HALFRECT) * SCALE;
            login_text.y = (player["y"] - PLAYER_HALFRECT - NICK_SHIFT_Y) * SCALE;
            container.addChild(login_text);

            //ХП
            moving_objects.graphics.beginStroke("black").beginFill("silver").drawRect(player["x"] * SCALE - PLAYER_HALFRECT * SCALE,
                (player["y"] - PLAYER_HALFRECT - HP_BAR_SHIFT_Y) * SCALE,
                SCALE * PLAYER_HALFRECT * 2, 0.3 * SCALE).endStroke();
            moving_objects.graphics.beginFill("#ed2123").drawRect(player["x"] * SCALE - PLAYER_HALFRECT * SCALE,
                (player["y"] - PLAYER_HALFRECT - HP_BAR_SHIFT_Y) * SCALE,
                SCALE * PLAYER_HALFRECT * 2 * player["hp"] / 100, 0.3 * SCALE);

            //ИГРОК
            if (p_sprites[player["login"]] == undefined) {
                p_sprites[player["login"]] = new createjs.Sprite(ss_player);
                p_sprites[player["login"]].gotoAndStop("run_right");
                p_sprites[player["login"]].scaleX = PLAYER_SCALE_X;
                p_sprites[player["login"]].scaleY = PLAYER_SCALE_Y;
            }

            var sprite = p_sprites[player["login"]];
            var curr_animation = ((player["vy"] != 0) ? "jump_" : "run_") + ((player["vx"] > 0) ? "right" : "left");
            if (player["vx"] == 0)
                sprite.stop();
            else if (curr_animation != sprite.currentAnimation || sprite.paused)
                sprite.gotoAndPlay(curr_animation);

            if (player["vy"] == 0 && player["vx"] == 0 && sprite.paused && sprite.currentAnimation.indexOf('jump') >= 0) {
                sprite.gotoAndStop(sprite.currentAnimation.indexOf('left') >= 0 ? "run_left" : "run_right");
            }

            container.addChild(sprite)
                .set({x: (player["x"] - PLAYER_SHIFT_X) * SCALE - PLAYER_HALFRECT * SCALE , y: (player["y"] - PLAYER_SHIFT_Y) * SCALE - PLAYER_HALFRECT * SCALE});
        }

        for (var i = 0; i < projectiles.length; ++i) {
            var projectile = projectiles[i];
            //console.log(projectile);
            moving_objects.graphics.beginStroke("black").beginFill("silver").drawCircle(projectile["x"] * SCALE ,
                projectile["y"] * SCALE, SCALE / 10);
        }

        for (var i = 0; i < items.length; ++i)
            map_items[i]["sprite"].gotoAndStop(items[i] == 0 ? map_items[i]["type"] : "empty")

        stage.addChild(container);
        scrollCanvas();
        stage.update();
       // console.log('onmessage, ' + event.data);
    };

    web_socket.onclose = function(event) {
        console.log('onclose');
    };
};


function draw_map(map)
{
    var Symbol = function(j, i) {
        return (i < 0 || j < 0 || i >= map[0].length || j >= map.length) ? "#" : map[j][i];
    };
    $("#canvas_wrapper").css("height", screen.height * 0.6)
    $("#main_canvas").attr("width", map[0].length * SCALE);
    $("#main_canvas").attr("height", (map.length + 1) * SCALE);
    stage = new createjs.Stage($("#main_canvas")[0]);
    rect = new createjs.Shape();
    rect.graphics.beginStroke("black").drawRect(0, 0, map[0].length * SCALE, (map.length + 1) * SCALE).endStroke();
    for (var j = 0; j < map.length; ++j)
        for (var i = 0; i < map[0].length; ++i)
        {
            if (map[j][i] == "#") {
                var wall_piece = get_map_wall_piece([
                    Symbol(j - 1, i - 1), Symbol(j - 1, i), Symbol(j - 1, i + 1), //top
                    Symbol(j, i - 1), Symbol(j, i + 1), //left/right
                    Symbol(j + 1, i - 1), Symbol(j + 1, i), Symbol(j + 1, i + 1), //bottom
                ]);

                stage.addChild(wall_piece).set({x: i * SCALE , y: j * SCALE});
            }
            else if (!isNaN(parseInt(map[j][i], 10))) {
                var teleport = new createjs.Sprite(ss_telepot, "show");
                teleport.scaleY = TELEPORT_SCALE_Y;
                teleport.scaleX = TELEPORT_SCALE_X;
                stage.addChild(teleport).set({x: (i - PLAYER_HALFRECT - TELEPORT_SHIFT_X) * SCALE, y: (j - PLAYER_HALFRECT - TELEPORT_SHIFT_Y) * SCALE});
                //rect.graphics.beginFill("green").drawCircle(i * SCALE + PLAYER_HALFRECT * SCALE, j * SCALE + PLAYER_HALFRECT * SCALE, SCALE / 5);
            }
            else if (/[a-z]/i.test(map[j][i])) {
                map_items.push({sprite: get_item(map[j][i]), type: map[j][i]});
                stage.addChild(map_items[map_items.length-1]["sprite"]).set({x: i * SCALE , y: j * SCALE});
            }
        }
    for (var i = 0; i < map[0].length; ++i) {
        stage.addChild(get_map_piece(16)).set({x: i * SCALE , y: map.length * SCALE});
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

function scrollCanvas(){
    var offset_x = 0;
    $("#canvas_wrapper").scrollLeft( offset_x = Math.min(Math.max(player_x * SCALE - $("#canvas_wrapper").width() / 2, 0), $("canvas").width() - $("#canvas_wrapper").width()) );
    $("#canvas_wrapper").scrollTop( Math.min(Math.max(player_y * SCALE - $("#canvas_wrapper").height() / 2, 0), $("canvas").height() - $("#canvas_wrapper").height()) );
    $('#canvas_wrapper').css('background-position-x', -1 * offset_x / 4);
}
