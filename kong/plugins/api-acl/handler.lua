local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.api-acl.access"

local ApiAclHandler = BasePlugin:extend()

function ApiAclHandler:new()
  ApiAclHandler.super.new(self, "api-acl")
end

function ApiAclHandler:init_worker()
  ApiAclHandler.super.init_worker(self)
end

function ApiAclHandler:access(conf)
  ApiAclHandler.super.access(self)
  access.execute(conf)
end

ApiAclHandler.PRIORITY = 1001

return ApiAclHandler
