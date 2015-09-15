local BaseDao = require "kong.dao.postgres.base_dao"
local consumers_schema = require "kong.dao.schemas.consumers"

local Consumers = BaseDao:extend()

function Consumers:new(properties)
  self._table = "consumers"
  self._schema = consumers_schema

  Consumers.super.new(self, properties)
end

-- @override
function Consumers:delete(where_t)
  local ok, err = Consumers.super.delete(self, where_t)
  if not ok then
    return false, err
  end

  -- delete all related plugins configurations
  -- FK delete cascading should handle this?

  return ok
end

return { consumers = Consumers }
