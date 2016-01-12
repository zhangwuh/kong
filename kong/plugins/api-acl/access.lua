local stringy = require "stringy"
local responses = require "kong.tools.responses"
local utils = require "kong.tools.utils"

local _M = {}

local function get_api_path()
  local uri = stringy.split(ngx.var.request_uri, "?")[1]
  if not stringy.endswith(uri, "/") then
    uri = uri.."/"
  end

  return uri
end

function _M.execute(conf)
  local block = false

  if utils.table_size(conf.blacklist) > 0 then
    local api_path = get_api_path()
    print("API PATH: ", api_path)

    for _, v in pairs(conf.blacklist) do
      print("API ENDPOINT IN BLACKLIST: ", v)
      if stringy.endswith(api_path, v) or stringy.endswith(api_path, v .. "/") then
        print("API IS BLOCKED DUE TO BALCKLIST", api_path, v)
        block = true;
      end
    end
  end

  if block then
    ngx.ctx.stop_phases = true -- interrupt other phases of this request
    return responses.send_HTTP_FORBIDDEN("The API endpoint is not allowed to call from your side.")
  end
end

return _M
