
const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81, KEY_MOUSE = "m",
    SCALE = 30, PLAYER_HALFRECT = 0.5, DEAD = "dead", KNIFE = "K", GUN = "P",
    NICK_SHIFT_Y = 0.5, HP_BAR_SHIFT_Y = 0.34,
    PLAYER_SCALE_X = 0.9, PLAYER_SCALE_Y = 0.8,
    WEAPON_SHIFT_X = 0.7, WEAPON_SHIFT_Y = 0.4,
    MAP_PIECE_SCALE = 0.5, PROJECTILE_SCALE = 0.3,
    TELEPORT_SCALE_X = 0.2, TELEPORT_SCALE_Y = 0.2, TELEPORT_SHIFT_Y = 0.8, TELEPORT_SHIFT_X = 0.8,
    MAIN_GAME_SHEETS = "assets/img/game2v1.png";
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

function compute_angle(x, y) {
    return (y < 0) ? Math.acos(-x / Math.sqrt(x * x + y * y)) * 180 / Math.PI + 180 : Math.acos(x / Math.sqrt(x * x + y * y)) * 180 / Math.PI
}

function get_sprite (sprite_sheet, param, scale, rotation) {
    var sprite = new createjs.Sprite(sprite_sheet);
    sprite.scaleY = scale;
    sprite.scaleX = Math.abs(scale);
    if (rotation != undefined)
        sprite.rotation = rotation;
    sprite.gotoAndStop(param);
    return sprite;
}

var ss_projectiles = new createjs.SpriteSheet({
    animations: {
        G: 0,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [200, 145, 55, 28, 0, 27, 14],
        [338, 210, 28, 28, 0, 14, 14],
    ],
});

function get_projectile (name, rotation) {
    var p = get_sprite(ss_projectiles, name, PROJECTILE_SCALE, rotation);
    return p;
}

var ss_weapon = new createjs.SpriteSheet({
    animations: {
        empty: 0,
        K: 1,
        P: 2,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [0, 0, 1, 1],
        [114, 330, 180, 44, 0, 50, 22],
        [66, 128, 116, 64, 0, 30, 30],
    ],
});


function get_weapon (name, rotation, direction) {
    return get_sprite(ss_weapon, name, direction > 0 ? MAP_PIECE_SCALE : -MAP_PIECE_SCALE, rotation);
}

var ss_items = new createjs.SpriteSheet({
    animations: {
        empty: 0,
        h: 1,
        P: 2,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [0, 0, 1, 1],
        [325, 72, 54, 48],
        [66, 128, 116, 64],
    ],
});

function get_item (name) {
    return get_sprite(ss_items, name, MAP_PIECE_SCALE);
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
        die: [15, 19, DEAD],
        dead: [14],
    },
    images: ["assets/img/walkcyclex.png"],
    frames: {
        height: 64,
        width: 64,
        regX: 14,
        regY: 20,
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
    return get_sprite(ss_map, piece_id, MAP_PIECE_SCALE);
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
        var last_shot = {}
        var items = data['items'];
        stage.removeChild(container);
        var moving_objects = new createjs.Shape();
        container = new createjs.Container();
        container.addChild(moving_objects);
        moving_objects.graphics.beginStroke("red");

        for (var i = 0; i < projectiles.length; ++i) {
            var projectile = projectiles[i];
            var angle = compute_angle(projectile["vx"], projectile["vy"]);
            container.addChild(get_projectile(projectile["weapon"], angle))
                .set({x: projectile["x"] * SCALE , y: projectile["y"] * SCALE});
            last_shot[projectile["owner"]] = angle;
        }

        for (var i = 0; i < players.length; ++i) {
            var player = players[i];
            if (p_sprites[player["login"]] == undefined) {
                p_sprites[player["login"]] = new createjs.Sprite(ss_player);
                p_sprites[player["login"]].gotoAndStop("run_right");
                p_sprites[player["login"]].scaleX = PLAYER_SCALE_X;
                p_sprites[player["login"]].scaleY = PLAYER_SCALE_Y;
            }
            var sprite = p_sprites[player["login"]];

            if (player["status"] == DEAD && sprite.currentAnimation == DEAD)
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

            if (player["status"] == DEAD && sprite.currentAnimation != "die")
                sprite.gotoAndPlay("die");

            if (player["status"] != DEAD) {
                var curr_animation = ((player["vy"] != 0) ? "jump_" : "run_") + ((player["vx"] >= 0) ? "right" : "left");
                if (player["vx"] == 0 && sprite.currentAnimation != DEAD)
                    sprite.stop();
                else if (curr_animation != sprite.currentAnimation || sprite.paused)
                    sprite.gotoAndPlay(curr_animation);

                if (player["vy"] == 0 && player["vx"] == 0 && sprite.paused && sprite.currentAnimation.indexOf('jump') >= 0) {
                    sprite.gotoAndStop(sprite.currentAnimation.indexOf('left') >= 0 ? "run_left" : "run_right");
                }
            }
            var p_x = player["x"] * SCALE  - PLAYER_HALFRECT * SCALE, p_y =  player["y"] * SCALE  - PLAYER_HALFRECT * SCALE;

            $('canvas:hover').css( 'cursor', 'url("assets/img/' + player["weapon"] + '_cursor.png") 30 30, auto' );

            if (player["status"] != DEAD)
                container.addChild(get_weapon(
                        player["weapon"],
                        (player["login"] == login ? compute_angle(mouse_x - p_x, mouse_y - p_y) :
                            (last_shot[player["login"]] ? last_shot[player["login"]] : 0)),
                        player["login"] == login ? mouse_x - p_x : 1
                    )
                ).set({x: p_x + PLAYER_HALFRECT * SCALE, y: p_y + PLAYER_HALFRECT * SCALE});


            container.addChild(sprite)
                .set({x: p_x , y: p_y});
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
