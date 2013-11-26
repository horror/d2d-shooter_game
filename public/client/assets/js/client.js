(function($){
var hostname = window.location.hostname.replace('www.',''), port = window.location.port;
$(document).on('click', 'a', function() {return false;});
tpl.loadTemplates(['login', 'lobby', 'chat_messages', 'game_list'], function() {

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
                that.set(data["params"]);
                callback();
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
/*+++++++++++++++++++++++++++++++++++++++++++++++++++ COLLECTIONS +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var AddNewUpdateActionCollection = Backbone.Collection.extend({
        url: 'http://' + hostname + ':' + port + '/',
        type: 'POST',
        contentType: 'application/json; charset=utf-8',

        addNew: function(data) {
            var m = new this.model();
            var that = this;
            data["params"]["sid"] = app.sid();
            m.send(data, function() {
                that.add(m);
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
/*+++++++++++++++++++++++++++++++++++++++++++++++++++ CONTROLLER +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var Controller = Backbone.Router.extend({
        routes: {
            "!/signin": "signin",
            "!/signup": "signup",
            "!/lobby": "lobby",
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
    });
    var controller = new Controller();

/*+++++++++++++++++++++++++++++++++++++++++++++++++++ APPLICATION +++++++++++++++++++++++++++++++++++++++++++++++++++ */
    var App = Backbone.View.extend({
        el: $("#container"),

        templates: { // Шаблоны на разное состояние
            signin: _.template(tpl.get('login')),
            signup: _.template(tpl.get('login')),
            lobby: _.template(tpl.get('lobby')),
        },

        models: {
            signin: [appState],
            signup: [appState],
        },

        collections: {
            lobby: [messages],
        },

        fetchAllColections: function() {
            $.each(this.collections, function(index, collection) {
                collection.map(function(item) {
                    var obj = {
                        data: item.data(),
                        type: 'POST',
                        contentType: 'application/json; charset=utf-8',
                    }
                    item.fetch(obj);
                });
            });
        },

        initialize: function () { // Подписка на событие модели
            _.bindAll(this, 'signin');
            this.model.bind('change', this.render, this);
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
                messages.addNew($('#game-form').serializeObjectAPI("createGame"));
                controller.navigate("!/lobby", true);
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
            var params = getTemplateAttrs(this.models[state]);
            this.$el.html(this.templates[state](params));
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