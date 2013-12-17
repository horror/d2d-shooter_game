
const KEY_UP = 38, KEY_DOWN = 40, KEY_LEFT = 37, KEY_RIGHT = 39, KEY_SPACE = 32, KEY_Q = 81, KEY_MOUSE = "m",
    SCALE = 30, PLAYER_HALFRECT = 0.5, DEAD = "dead",
    KNIFE = "K", GUN = "P", MACHINE_GUN = "M", ROCKET_LAUNCHER = "R", RAIL_GUN = "A",
    X = 0, Y = 1, VX = 2, VY = 3, WEAPON = 4, WEAPON_ANGLE = 5, TICKS = 5, LOGIN = 6, HP = 7, RESPAWN = 8, KILLS = 9, DEATHS = 10,
    NICK_SHIFT_Y = 0.5, HP_BAR_SHIFT_Y = 0.34,
    PLAYER_SCALE_X = 0.9, PLAYER_SCALE_Y = 0.8,
    MAP_PIECE_SCALE = 0.5, PROJECTILE_SCALE = 0.3, WEAPON_SCALE = 0.35,
    TELEPORT_SCALE = 0.2, EXPLOSION_SCALE = 0.2,
    MAIN_GAME_SHEETS = "assets/img/main_game.png";
var keys_to_params = {
        "m": {"action": "fire", params: {}},
        38: {"action": "move", "params": {"dx": 0, "dy": -1}},
        40: {"action": "move", "params": {"dx": 0, "dy": 1}},
        37: {"action": "move", "params": {"dx": -1, "dy": 0}},
        39: {"action": "move", "params": {"dx": 1, "dy": 0}},
        81: {"action": "empty", "params": {}}
    },
    ticks_want_to_draw = {
        "K": 1000,
        "P": 1,
        "M": 1,
        "R": 3,
        "A": 0,
    },
    hostname = window.location.hostname.replace('www.',''), port = window.location.port,
    web_socket_url = 'ws://' + hostname + ':8001', server_url = 'http://' + hostname + ':' + port, tick = 0,
    stage, container, web_socket, player_x = 0, player_y = 0, view_port_offset_x = 0, view_port_offset_y = 0,
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

var ss_effects = new createjs.SpriteSheet({
    animations: {
        teleport: {
            frames: [0, 2, 4, 6, 8, 10],
            speed: 0.8,
        },
        explosion: {
            frames: [1, 3, 5, 7, 9, 11, 13, 15, 17, 16],
            next: false,
            speed: 2,
        },
    },
    images: ["assets/img/effects.png"],
    frames: {
        height: 512,
        width: 512,
        regX: 256,
        regY: 256,
    },
});

function get_effect(name, scale) {
    var effect = new createjs.Sprite(ss_effects, name);
    effect.scaleY = effect.scaleX = scale;
    return effect;
}

var ss_projectiles = new createjs.SpriteSheet({
    animations: {
        K: 0,
        P: 1,
        M: 2,
        R: 3,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [0, 0, 1, 1],
        [200, 145, 55, 28, 0, 27, 14],
        [338, 210, 28, 28, 0, 14, 14],
        [318, 268, 64, 38, 0, 32, 19],
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
        M: 3,
        R: 4,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [0, 0, 1, 1],
        [114, 330, 180, 44, 0, 50, 22],
        [68, 128, 116, 64, 0, 30, 30],
        [68, 196, 226, 58, 0, 110, 22],
        [68, 260, 212, 64, 0, 100, 22],
    ],
});


function get_weapon (name, rotation, direction) {
    return get_sprite(ss_weapon, name, direction >= 0 ? WEAPON_SCALE : -WEAPON_SCALE, rotation);
}

var ss_items = new createjs.SpriteSheet({
    animations: {
        empty: 0,
        h: 1,
        P: 2,
        M: 3,
        R: 4,
    },
    images: [MAIN_GAME_SHEETS],
    frames: [
        [0, 0, 1, 1],
        [325, 72, 54, 48],
        [68, 128, 116, 64],
        [68, 196, 226, 58],
        [68, 260, 212, 64],
    ],
});

function get_item (name) {
    return get_sprite(ss_items, name, (name == "h") ? MAP_PIECE_SCALE : WEAPON_SCALE);
}

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

function get_text(text, x, y) {
    var text = new createjs.Text(text, "12px Arial", "black");
    text.textBaseline = "alphabetic";
    text.x = x;
    text.y = y;
    return text
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
        scrollCanvas();
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

        for (var i = 0; i < projectiles.length; ++i) {
            var projectile = projectiles[i];
            var angle = compute_angle(projectile[VX], projectile[VY]);
            if (projectile[TICKS] > ticks_want_to_draw[projectile[WEAPON]] || projectile[VX] == 0 && projectile[VY] == 0) {
                projectile[WEAPON] == ROCKET_LAUNCHER && projectile[VX] == 0 && projectile[VY] == 0 ?
                    stage.addChild(get_effect("explosion", EXPLOSION_SCALE)).set({x: projectile[X] * SCALE , y: projectile[Y] * SCALE}) :
                    container.addChild(get_projectile(projectile[WEAPON], angle)).set({x: projectile[X] * SCALE , y: projectile[Y] * SCALE});
            }
        }

        for (var i = 0; i < players.length; ++i) {
            var player = players[i];
            if (p_sprites[player[LOGIN]] == undefined) {
                p_sprites[player[LOGIN]] = new createjs.Sprite(ss_player);
                p_sprites[player[LOGIN]].gotoAndStop("run_right");
                p_sprites[player[LOGIN]].scaleX = PLAYER_SCALE_X;
                p_sprites[player[LOGIN]].scaleY = PLAYER_SCALE_Y;
            }
            var sprite = p_sprites[player[LOGIN]];

            if (player[RESPAWN] > 0 && sprite.currentAnimation == DEAD)
                continue;

            if (player[LOGIN] == login) {
                player_x = player[X];
                player_y = player[Y];
            }
            //СТАТИСТИКА
            container.addChild(get_text(player[LOGIN] + " - kills:" + player[KILLS] + ", death:" + player[DEATHS],
                40 + view_port_offset_x, (i * 10 + 1) + view_port_offset_y));

            //НИК
            container.addChild(get_text(player[LOGIN], (player[X] - PLAYER_HALFRECT) * SCALE,
                (player[Y] - PLAYER_HALFRECT - NICK_SHIFT_Y) * SCALE));

            //ХП
            moving_objects.graphics.beginStroke("black").beginFill("silver").drawRect(player[X] * SCALE - PLAYER_HALFRECT * SCALE,
                (player[Y] - PLAYER_HALFRECT - HP_BAR_SHIFT_Y) * SCALE,
                SCALE * PLAYER_HALFRECT * 2, 0.3 * SCALE).endStroke();
            moving_objects.graphics.beginFill("#ed2123").drawRect(player[X] * SCALE - PLAYER_HALFRECT * SCALE,
                (player[Y] - PLAYER_HALFRECT - HP_BAR_SHIFT_Y) * SCALE,
                SCALE * PLAYER_HALFRECT * 2 * player[HP] / 100, 0.3 * SCALE);

            //ИГРОК

            if (player[RESPAWN] > 0 && sprite.currentAnimation != "die")
                sprite.gotoAndPlay("die");

            if (player[RESPAWN] == 0) {
                var curr_animation = ((player[VY] != 0) ? "jump_" : "run_") + ((player[VX] >= 0) ? "right" : "left");
                if (player[VX] == 0 && sprite.currentAnimation != DEAD)
                    sprite.stop();
                else if (curr_animation != sprite.currentAnimation || sprite.paused)
                    sprite.gotoAndPlay(curr_animation);

                if (player[VY] == 0 && player[VX] == 0 && sprite.paused && sprite.currentAnimation.indexOf('jump') >= 0) {
                    sprite.gotoAndStop(sprite.currentAnimation.indexOf('left') >= 0 ? "run_left" : "run_right");
                }
            }
            var p_x = player[X] * SCALE  - PLAYER_HALFRECT * SCALE, p_y =  player[Y] * SCALE  - PLAYER_HALFRECT * SCALE;

            if (player[LOGIN] == login)
                $('canvas:hover').css( 'cursor', 'url("assets/img/' + player[WEAPON] + '_cursor.png") 15 15, auto' );

            if (player[RESPAWN] == 0)
                container.addChild(get_weapon(
                        player[WEAPON],
                        (player[LOGIN] == login ?
                            compute_angle(mouse_x - p_x, mouse_y - p_y) : player[WEAPON_ANGLE]),
                        player[LOGIN] == login ?
                            mouse_x - p_x : -1 * (player[WEAPON_ANGLE] < 270 && player[WEAPON_ANGLE] > 90)
                    )
                ).set({x: p_x + PLAYER_HALFRECT * SCALE, y: p_y + PLAYER_HALFRECT * SCALE});

            mouse_pressed = false;
            container.addChild(sprite)
                .set({x: p_x , y: p_y});
        }

        for (var i = 0; i < items.length; ++i)
            map_items[i]["sprite"].gotoAndStop(items[i] == 0 ? map_items[i]["type"] : "empty")

        stage.addChild(container);
        stage.update();
        console.log('onmessage, ' + event.data);
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
                stage.addChild(get_effect("teleport", TELEPORT_SCALE)).set({x: (i + PLAYER_HALFRECT) * SCALE, y: (j + PLAYER_HALFRECT) * SCALE});
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

            if (web_socket.readyState == 1)
                web_socket.send(JSON.stringify(arr));

        }
    if (pressed)
        setTimeout("key_hold('" + sid + "')", 20);
}

function scrollCanvas(){
    $("#canvas_wrapper").scrollLeft(view_port_offset_x = Math.min(Math.max(player_x * SCALE - $("#canvas_wrapper").width() / 2, 0), $("canvas").width() - $("#canvas_wrapper").width()) );
    $("#canvas_wrapper").scrollTop(view_port_offset_y = Math.min(Math.max(player_y * SCALE - $("#canvas_wrapper").height() / 2, 0), $("canvas").height() - $("#canvas_wrapper").height()) );
    $('#canvas_wrapper').css('background-position-x', -1 * view_port_offset_x / 4);
}
