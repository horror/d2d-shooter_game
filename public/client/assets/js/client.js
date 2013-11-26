(function($){
$(document).on('click', 'a', function() {return false;});
tpl.loadTemplates(['header', 'login', 'lobby', 'chat_messages', 'game_list', 'new_game', 'new_map', 'run_game'], function() {

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++ MODELS +++++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var AppState = Backbone.Model.extend({
        defaults: {
            sid: $.cookie("sid"),
            state: "",
            chatRefrashIntervalHandler: "",
            gameListRefrashIntervalHandler: "",
        },
        name: "AppState",
        signin: function(sid) {
            this.set({sid: sid});
            $.cookie("sid", sid);
        },
        signout: function () {
            this.set({sid: undefined});
            $.removeCookie("sid");
        },
    });
    var appState = new AppState();

    appState.bind("change:state", function () { // подписка на смену состояния для контроллера
        var state = this.get("state");

        if (state != "signup" && state != "signin" && !this.get("sid")) { //незалогинился
            controller.navigate("!/signin", true);
            return;
        }

        if (this.get("sid") && curr_game.get("id") && state != "runGame") { //продолжить играть
            controller.navigate("!/run_game", true);
            return;
        }

        if (state == "runGame" && !curr_game.get("id")) { //перейти в лобби, если мы уже не играем
            controller.navigate("!/lobby", true);
            return;
        }

        (state == "runGame") ? messages.curr_game_params() :  messages.lobby_params();

        if (state == "lobby" || state == "runGame") {
            this.chatRefrashIntervalHandler = setInterval(function(){

                messages.update(function(){
                    $("#chat_messages").html( _.template(tpl.get('chat_messages'))({Messages: messages.toJSON()}));
                });
            },1000);

            if (state == "lobby")
                this.gameListRefrashIntervalHandler = setInterval(function(){
                    games.update(function(){
                        $("#games").html( _.template(tpl.get('game_list'))({Games: games.toJSON()}));
                    });
                },6000);
        }
        else
            clearInterval(this.chatRefrashIntervalHandler);

        if (state == "runGame")
            clearInterval(this.gameListRefrashIntervalHandler);
    });

    var SendActionModel = Backbone.Model.extend({
        send: function(data, callback) {
            var that = this;
            sendRequest(data, function (response){
                process(response, function() {
                    that.set(data["params"]);
                    callback();
                });
            });
        },
    });

    var Game = SendActionModel.extend({
        defaults: {
            id: '',
            name: '',
            map: '',
            maxPlayers: '',
        },
        name: "Game",

        refreshData: function (callback) {
            var that = this;
            if (!that.get('id')) {
                if (callback != undefined)
                    callback();
                return;
            }
            games.update(function () {
                if (games.length == 0) {
                    if (callback != undefined)
                        callback();
                    return;
                }
                games.each(function (game) {
                    var game = game.toJSON();
                    if (game['id'] == that.get('id'))
                        that.set(game);
                    maps.update(function () {
                        maps.each(function (map) {
                            var map = map.toJSON();
                            if (map['name'] == that.get('map')) {
                                that.set({mapData: JSON.stringify(map['map'])});
                                if (callback != undefined)
                                    callback();
                            }
                        })
                    });
                })
            });
        },

        join: function (id, callback) {
            this.set({id: id});
            $.cookie("game_id", id);
            this.refreshData(callback);
        },
        leave: function (id) {
            this.set({id: undefined});
            $.removeCookie("game_id");
        }
    });
    var curr_game = new Game({id: $.cookie("game_id")});

    var Message = SendActionModel.extend({
        defaults: {
            sid: '',
            text: '',
            game: '',
        },
        name: "Message",
    });

    var Map = SendActionModel.extend({
        defaults: {
            sid: '',
            name: '',
            map: '',
            maxPlayers: '',
        },
        name: "Map",
    });
/*+++++++++++++++++++++++++++++++++++++++++++++++++++ COLLECTIONS +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var AddNewUpdateActionCollection = Backbone.Collection.extend({
        url: 'http://' + hostname + ':' + port + '/',
        type: 'POST',
        contentType: 'application/json; charset=utf-8',

        addNew: function(data, callback) {
            var m = new this.model();
            var that = this;
            data["params"]["sid"] = appState.get("sid");
            if (that.name == "Maps")
                data["params"]["map"] = data["params"]["map"].split("\r\n");
            m.send(data, function() {
                that.add(m);
                if (callback != undefined)
                    callback();
            });
        },

        update: function (callback) {
            this.fetch({
                success: callback,
                data: this.data(),
                type: this.type,
                contentType: this.contentType,
            });
        },

        params: {
            sid: appState.get('sid'),
        },

        getAction: function () {
            return this.action;
        },

        getParams: function () {
            this.params['sid'] = appState.get('sid') //обновляем сид перед запросом
            return this.params;
        },

        defineParams: function (params) {
            this.params = params;
        },

        data: function() { return JSON.stringify({
                action: this.getAction(),
                params: this.getParams(),
            })
        },
    });

    var Messages = AddNewUpdateActionCollection.extend({
        model: Message,

        action: "getMessages",

        params: {
            sid: appState.get('sid'),
            game: "",
            since: 0,//new Date().getTime(),
        },

        curr_game_params: function () {
            this.params['game'] = curr_game.get('id') * 1;
        },

        lobby_params: function () {
            this.params['game'] = "";
        },

        parse: function(response){
            return response.messages.reverse();
        },
        name: "Messages",
    });
    var messages = new Messages;

    var Games = AddNewUpdateActionCollection.extend({
        model: Game,

        action: "getGames",

        parse: function(response){
            return response.games;
        },
        name: "Games",
    });
    var games = new Games;

    var Maps = AddNewUpdateActionCollection.extend({
        model: Map,

        action: "getMaps",

        parse: function(response){
            return response.maps;
        },
        name: "Maps",
    });
    var maps = new Maps;
/*+++++++++++++++++++++++++++++++++++++++++++++++++++ CONTROLLER +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var Controller = Backbone.Router.extend({
        routes: {
            "!/signin": "signin",
            "!/signup": "signup",
            "!/lobby": "lobby",
            "!/new_game": "newGame",
            "!/new_map": "newMap",
            "!/run_game": "runGame",
        },

        signin: function () {
            appState.set({ state: "signin" });
        },

        signup: function () {
            appState.set({ state: "signup" });
        },

        lobby: function () {
            appState.set({ state: "lobby" });
        },

        newGame: function () {
            appState.set({ state: "newGame" });
        },

        newMap: function () {
            appState.set({ state: "newMap" });
        },

        runGame: function () {
            appState.set({ state: "runGame" });
        },
    });
    var controller = new Controller();

/*+++++++++++++++++++++++++++++++++++++++++++++++++++ APPLICATION +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var App = Backbone.View.extend({
        el: $("#container"),

        header: function () {
            return _.template(tpl.get('header'))(this.model.toJSON());
        },

        templates: { // Шаблоны на разное состояние
            signin: _.template(tpl.get('login')),
            signup: _.template(tpl.get('login')),
            lobby: _.template(tpl.get('lobby')),
            newGame: _.template(tpl.get('new_game')),
            newMap: _.template(tpl.get('new_map')),
            runGame: _.template(tpl.get('run_game')),
        },

        models: {
            signin: [appState],
            signup: [appState],
            runGame: [curr_game, appState],
        },

        collections: {
            newGame: [maps],
        },

        refresh: function() {
            var that = this;
            $.each(that.collections, function(index, collections) {
                collections.map(function(collection) {
                    collection.update(function() {});
                });
            });
            that.render();
        },

        initialize: function () { // Подписка на событие модели
            _.bindAll(this, 'signin');
            this.model.bind('change', this.refresh, this);

            maps.bind("add change remvoe", this.render, this);
        },

        events: {
            'click a#signin': 'signin',
            'click a#signup': 'signup',
            'click a#signout': function () {
                sendRequest({action: "signout", params: {sid: this.sid()}}, function(response) {
                    appState.signout();
                    controller.navigate("!/signin", true);
                });
            },
            'click a#to_signup': function () {
                controller.navigate("!/signup", true);
            },
            'click a#send_message': function () {
                messages.addNew($('#chat-form').serializeObjectAPI("sendMessage"));
                $('#message_text').val("");
            },
            'click a#create_game': function () {
                var data = $('#game-form').serializeObjectAPI("createGame");
                var game_name = data["params"]["name"];
                games.addNew(data, function () {
                    games.update(function () {
                        games.each(function(game) {
                            game = game.toJSON();
                            if (game["name"] == game_name)
                                curr_game.join(game["id"], function () {
                                    controller.navigate("!/run_game", true);
                                });
                        });
                    });
                });
            },
            'click a.join_game': function (e) {
                e.preventDefault();
                var game_id = $(e.currentTarget).attr("id");
                sendRequest({action: "joinGame", params: {sid: this.sid(), game: game_id}}, function(response) {
                    process(response, function () {
                        curr_game.join(game_id, function () {
                            controller.navigate("!/run_game", true);
                        });
                    });
                });
            },
            'click a#leave_game': function () {
                sendRequest({action: "leaveGame", params: {sid: this.sid()}}, function(response) {
                    process(response, function () {
                        curr_game.leave();
                        controller.navigate("!/lobby", true);
                    });
                });
            },
            'click a#to_new_game': function () {
                controller.navigate("!/new_game", true);
            },
            'click a#to_new_map': function () {
                controller.navigate("!/new_map", true);
            },
            'click a#upload_map': function () {
                maps.addNew($('#map-form').serializeObjectAPI("uploadMap"), function () {
                    controller.navigate("!/new_game", true);
                });
            },
        },

        signin: function () {
            sendRequest($('#form-signin').serializeObjectAPI("signin"), function(response) {
                process(response, function(){
                    appState.signin(response["sid"]);
                    controller.navigate("!/lobby", true);
                });
            })
        },

        signup: function () {
            var that = this;
            sendRequest($('#form-signin').serializeObjectAPI("signup"), function(response) {
                process(response, that.signin);
            })
        },

        render: function(){
            var state = this.state();
            var params = getTemplateAttrs(this.models[state], this.collections[state]);
            this.$el.html(this.header() + this.templates[state](params));
            return this;
        },

        state: function (state) {
            if (state != undefined)
                this.model.set({state: state})
            return this.model.get("state");
        },

        sid: function (sid) {
            if (sid != undefined)
                this.model.set({sid: sid})
            return this.model.get("sid");
        },

        in_game: function () {
            return curr_game.get("id") && this.sid();
        },
    });

    curr_game.refreshData(function () {
        new App({ model: appState });

        Backbone.history.start();
        appState.set({ state: "runGame" });
    });
});})(jQuery);