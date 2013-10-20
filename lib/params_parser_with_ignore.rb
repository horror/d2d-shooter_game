require 'action_dispatch/http/request'

module MyApp
  class ParamsParser < ActionDispatch::ParamsParser
    def initialize(app, opts = {})
      @app = app
      @opts = opts
      super
    end

    def call(env)
      if @opts[:ignore_prefix].nil? or !env['PATH_INFO'].start_with?(@opts[:ignore_prefix])
        super(env)
      else
        begin
          rq = ActionDispatch::Request.new(env)
          json = rq.body.string
          ActiveSupport::JSON.decode(json)
        rescue
          env["action_dispatch.request.request_parameters"] = {"json parser exception" => "bad json"}
          @app.call(env)
        else
          super(env)
        ensure
        end
      end
    end
  end
end