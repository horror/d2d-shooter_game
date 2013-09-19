module Requests
  module JsonHelpers
    def enc(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def dec(str)
      ActiveSupport::JSON.decode(str)
    end

    def send_request(obj)
      xhr :post, "/", enc(obj), "CONTENT_TYPE" => 'application/json; charset=utf-8', "DATA_TYPE" => 'json'
    end
  end
end