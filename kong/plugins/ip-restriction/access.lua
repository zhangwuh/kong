local iputils = require "resty.iputils" 
local responses = require "kong.tools.responses"
local utils = require "kong.tools.utils"

local _M = {}

function _M.execute(conf)
  local block = false
  local in_white_list = false

  if utils.table_size(conf.blacklist) > 0 then
    if iputils.ip_in_cidrs(ngx.var.remote_addr, conf._blacklist_cache) then
      block = true
    end
  end

  if utils.table_size(conf.whitelist) > 0 then
    if iputils.ip_in_cidrs(ngx.var.remote_addr, conf._whitelist_cache) then
      in_white_list = true
    end
  end

  if block then
    ngx.ctx.stop_phases = true -- interrupt other phases of this request
    return responses.send_HTTP_FORBIDDEN("Your IP address is not allowed")
  end

  if in_white_list then
    ngx.ctx.stop_auth = true -- interrupt other auth plugins cos the IP is in white list
  end
end

return _M
