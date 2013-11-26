var hostname = window.location.hostname.replace('www.',''), port = window.location.port;

tpl = {

    // Hash of preloaded templates for the app
    templates:{},

    // Recursively pre-load all the templates for the app.
    // This implementation should be changed in a production environment. All the template files should be
    // concatenated in a single file.
    loadTemplates:function (names, callback) {

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

    // Get template by name from hash of preloaded templates
    get:function (name) {
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
            var m_name = model.name;
            result[m_name] = {};
            for (var attr in model.attributes)
                result[m_name][attr] = model.attributes[attr];
        });

    if (collections != undefined)
        $.each(collections, function(index, collection) {
            var c_name = collection.name;
            result[c_name] = [];
            var items = collection.map(function(item) { return item.attributes});
            $.each(items, function(index, item) {
                result[c_name].push(item);
            });
        });

    return result;
}

function sendRequest(data, callback) {
    $.ajax({
        url: 'http://' + hostname + ':' + port + '/',
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
