(function($){
$(document).on('click', 'a', function() {return false;});
tpl.loadTemplates(['header', 'login', 'lobby', 'chat_messages', 'game_list', 'new_game'], function() {

/*+++++++++++++++++++++++++++++++++++++++++++++++++++++ MODELS +++++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var AppState = Backbone.Model.extend({
        defaults: {
            sid: $.cookie("sid"),
            state: "",
            chatRefrashIntervalHandler: "",
            gameListRefrashIntervalHandler: "",
        },
        name: "AppState"
    });
    var appState = new AppState();

    appState.bind("change:state", function () { // подписка на смену состояния для контроллера
        var state = this.get("state");
        if (state != "signup" && state != "signin" && !this.get("sid")) {
            controller.navigate("!/signin", true);
            return;
        }
        if (state == "lobby") {
            this.chatRefrashIntervalHandler = setInterval(function(){
                messages.update(function(){
                    $("#chat_messages").html( _.template(tpl.get('chat_messages'))({Messages: messages.toJSON()}));
                });
            },1000);
            this.gameListRefrashIntervalHandler = setInterval(function(){
                games.update(function(){
                    $("#games").html( _.template(tpl.get('game_list'))({Games: games.toJSON()}));
                });
            },6000);
        }
        else {
            clearInterval(this.chatRefrashIntervalHandler);
            clearInterval(this.gameListRefrashIntervalHandler);
        }
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
            sid: '',
            name: '',
            map: '',
            maxPlayers: '',
        },
        name: "Game",
    });

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
            data["params"]["sid"] = app.sid();
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
                data: this.data(),
                type: this.type,
                contentType: this.contentType,
            });
        }
    });

    var Messages = AddNewUpdateActionCollection.extend({
        model: Message,

        data: function(){ return JSON.stringify({
            action: "getMessages",
            params: {
                sid: appState.get('sid'),
                game: "",
                since: 0,//new Date().getTime(),

            }})
        },

        parse: function(response){
            return response.messages.reverse();
        },
        name: "Messages",
    });
    var messages = new Messages;

    var Games = AddNewUpdateActionCollection.extend({
        model: Game,

        data: function(){ return JSON.stringify({
            action: "getGames",
            params: {
                sid: appState.get('sid'),
            }})
        },
        parse: function(response){
            return response.games;
        },
        name: "Games",
    });
    var games = new Games;

    var Maps = AddNewUpdateActionCollection.extend({
        model: Map,

        data: function(){ return JSON.stringify({
            action: "getMaps",
            params: {
                sid: appState.get('sid'),
            }})
        },
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
        },

        models: {
            signin: [appState],
            signup: [appState],
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
                    appState.set({sid: undefined});
                    $.removeCookie("sid");
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
                messages.addNew($('#game-form').serializeObjectAPI("createGame"), function () {
                    controller.navigate("!/lobby", true);//"!/game"
                });
            },
            'click a#to_new_game': function () {
                controller.navigate("!/new_game", true);
            },
        },

        signin: function () {
            var that = this;
            sendRequest($('#form-signin').serializeObjectAPI("signin"), function(response) {
                process(response, function(){
                    that.sid(response["sid"]);
                    $.cookie("sid", that.sid());
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
        }
    });
    var app = new App({ model: appState });

    Backbone.history.start();

    if ((app.state() == "" || app.state() != "signup") && app.sid() === undefined)
        controller.navigate("!/signin", true);
    else if (app.state() == "" && app.sid() != "")
        controller.navigate("!/lobby", true);

    console.log(app.sid())
});})(jQuery);