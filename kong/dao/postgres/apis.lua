local BaseDao = require "kong.dao.postgres.base_dao"
local apis_schema = require "kong.dao.schemas.apis"
local query_builder = require "kong.dao.postgres.query_builder"

local Apis = BaseDao:extend()

function Apis:new(properties)
  self._table = "apis"
  self._schema = apis_schema
  Apis.super.new(self, properties)
end

function Apis:find_all()
  local select_q = query_builder.select(self._table)
  local apis, err = Apis.super.execute(self, select_q)
    if err then
      return nil, err
    end

  return apis
end

-- @override
function Apis:delete(where_t)
  local ok, err = Apis.super.delete(self, where_t)
  if not ok then
    return false, err
  end

  -- delete all related plugins configurations
  -- delete cascading should handle this

  return ok
end

return {apis = Apis}
