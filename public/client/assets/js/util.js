var hostname = window.location.hostname.replace('www.',''), port = window.location.port;

tpl = {
    templates: {},

    loadTemplates: function (names, callback) {

        var that = this;

        var loadTemplate = function (index) {
            var name = names[index];
            console.log('Loading template: ' + name);
            $.get('views/' + name + '.html', function (data) {
                that.templates[name] = data;
                index++;
                if (index < names.length) {
                    loadTemplate(index);
                } else {
                    callback();
                }
            })
        }

        loadTemplate(0);
    },

    get: function (name) {
        return this.templates[name];
    }

};

$.fn.serializeObjectAPI = function(action)
{
    var o = {};
    o["action"] = action;
    o["params"] = {};
    var a = this.serializeArray();
    $.each(a, function() {
        if (this.value == parseInt(this.value))
            this.value = parseInt(this.value);

        if (o["params"][this.name] !== undefined) {
            if (!o["params"][this.name].push) {
                o["params"][this.name] = [o["params"][this.name]];
            }
            o["params"][this.name].push(this.value || '');
        } else {
            o["params"][this.name] = this.value || '';
        }
    });
    return o;
};

function getTemplateAttrs(models, collections) {
    var result = {};

    if (models != undefined)
        $.each(models, function(index, model) {
            var mName = model.name;
            result[mName] = {};
            for (var attr in model.attributes)
                result[mName][attr] = model.attributes[attr];
        });

    if (collections != undefined)
        $.each(collections, function(index, collection) {
            var cName = collection.name;
            result[cName] = [];
            var items = collection.map(function(item) { return item.attributes});
            $.each(items, function(index, item) {
                result[cName].push(item);
            });
        });

    return result;
}

function sendRequest(data, callback) {
    $.ajax({
        url: 'http://' + hostname + ':' + port + '/',
        timeout: 8000,
        type: 'POST',
        data: JSON.stringify(data),
        contentType: 'application/json; charset=utf-8'
    }).done(function(msg) {
            callback(msg);
            console.log(msg);
    }).fail(function(jqXHR, msg) {
        alert(msg);
    });
}

function validationError(response) {
    var err_message = response["message"] ? response["message"] : response["result"];
    $("#validation_error").html( '<div class="alert alert-danger">' + err_message + '</div>');
}

function process(response, callback) {
    if (response["result"] == "ok") {
        callback();
    }
    else
        validationError(response);
}

function updateModel(handler, data, callback) {
    var that = handler;
    sendRequest(data, function (response){
        that.set(data["params"]);
        callback();
    });
}
