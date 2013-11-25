(function($){
var hostname = window.location.hostname.replace('www.',''), port = window.location.port;
$(document).on('click', 'a', function() {return false;});
tpl.loadTemplates(['login', 'lobby', 'chat_messages'], function() {
    var AppState = Backbone.Model.extend({
        defaults: {
            sid: $.cookie("sid"),
            state: "",
            chatRefrashIntervalHandler: "",
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
        if (state == "lobby")
            this.chatRefrashIntervalHandler = setInterval(function(){
                messages.fetch({
                    success: function(){
                        $("#chat_messages").html( _.template(tpl.get('chat_messages'))({Messages: messages.toJSON()}));
                    },
                    data: messages.data(),
                    type: 'POST',
                    contentType: 'application/json; charset=utf-8',
                });
            },1000);
        else
            clearInterval(this.chatRefrashIntervalHandler);
    });

    var Message = Backbone.Model.extend({
        defaults: {
            sid: '',
            text: '',
            game: '',
        },
        send: function(data, callback) {
            var that = this;
            sendRequest(data, function (response){
                that.set(data["params"]);
                callback();
            });
        },
        name: "Message",
    });

    var Messages = Backbone.Collection.extend({
        model: Message,
        url: 'http://' + hostname + ':' + port + '/',
        data: function(){ return JSON.stringify({
            action: "getMessages",
            params: {
                sid: appState.get('sid'),
                game: "",
                since: 0,//new Date().getTime(),

            }})
        },
        addNew: function(data) {
            var m = new Message();
            var that = this;
            data["params"]["sid"] = app.sid();
            m.send(data, function() {
                that.add(m);
            });
        },
        parse: function(response){
            return response.messages.reverse();
        },
        name: "Messages",
    });
    var messages = new Messages;

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
    var controller = new Controller(); // Создаём контроллер


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

    messages.bind('add', function(message) {
        messages.fetch({success: function(){app.render();}});
    });

    Backbone.history.start();

    if ((app.state() == "" || app.state() != "signup") && app.sid() === undefined)
        controller.navigate("!/signin", true);
    else if (app.state() == "" && app.sid() != "")
        controller.navigate("!/lobby", true);

    console.log(app.sid())
});})(jQuery);