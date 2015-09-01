local _M = {}

function _M.set_database(database)
  _M.database = database
  _M.BaseDao = require('kong.dao.'..database..'.base_dao')
end

return _M
