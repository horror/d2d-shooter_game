module Requests
  module JsonHelpers
    def enc(obj)
      ActiveSupport::JSON.encode(obj)
    end

    def dec(str)
      ActiveSupport::JSON.decode(str)
    end
  end
end