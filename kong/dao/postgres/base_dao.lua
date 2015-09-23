local query_builder = require "kong.dao.postgres.query_builder"
local validations = require "kong.dao.schemas_validation"
local constants = require "kong.constants"
local pgmoon = require "pgmoon"
local DaoError = require "kong.dao.error"
local Object = require "classic"
local utils = require "kong.tools.utils"
local uuid = require "uuid"

local error_types = constants.DATABASE_ERROR_TYPES

local BaseDao = Object:extend()

--for dbnull values
local dbnull = pgmoon.new().null
-- This is important to seed the UUID generator
uuid.seed()

function BaseDao:new(properties)
  if self._schema then
    self._primary_key = self._schema.primary_key
    self._clustering_key = self._schema.clustering_key
    local indexes = {}
    for field_k, field_v in pairs(self._schema.fields) do
      if field_v.queryable then
        indexes[field_k] = true
      end
    end
  end

  self._properties = properties
  self._statements_cache = {}
end

-- Marshall an entity. Does nothing by default,
-- must be overriden for entities where marshalling applies.
function BaseDao:_marshall(t)
  return t
end

-- Unmarshall an entity. Does nothing by default,
-- must be overriden for entities where marshalling applies.
function BaseDao:_unmarshall(t)
  return t
end

-- Open a connection to the postgres database.
-- @return `pg` Opened postgres connection
-- @return `error`   Error if any
function BaseDao:_open_session()
  local ok, err

  -- Start postgres session
  local pg = pgmoon.new({
    host = self._properties.hosts,
    port = self._properties.port,
    database = self._properties.keyspace,
    user = self._properties.username,
    password = self._properties.password
  })
  ok, err = pg:connect()

  if not ok then
    return nil, DaoError(err, error_types.DATABASE)
  end
  return pg
end

-- Close the given opened session.
-- Will try to put the session in the socket pool if supported.
-- @param `pg` postgres session to close
-- @return `error`  Error if any
function BaseDao:_close_session(pg)
  -- Back to the pool or close if using luasocket
  local ok, err
  -- if ngx and ngx.get_phase ~= nil and ngx.get_phase() ~= "init" and ngx.socket.tcp ~= nil and ngx.socket.tcp().setkeepalive ~= nil then
  --   -- openresty
  -- -- something here ain't working within lapis? sock.setkeepalive is nil although we're in an ngx context
  --   ok, err = pg:keepalive()
  --   if not ok then
  --     return DaoError(err, error_types.DATABASE)
  --   end
  -- else
    ok, err = pg:disconnect()
    if not ok then
      return DaoError(err, error_types.DATABASE)
    end
  -- end

  if not ok then
    return DaoError(err, error_types.DATABASE)
  end
end

-- Execute a sql query.
-- Opens a socket, executes the query, puts the socket back into the
-- socket pool and returns a parsed result.
-- @param `query` plain string query.
-- @return `results`  If results set are ROWS, a table with an array of unmarshalled rows
-- @return `error`    An error if any during the whole execution (sockets/query execution)
function BaseDao:_execute(query)
  local pg, err = self:_open_session()
  if err then
    return nil, err
  end

  local results, errorOrRows = pg:query(query)

  if string.find(errorOrRows, 'ERROR') then
    err = errorOrRows
  end

  if err then
    err = DaoError(err, error_types.DATABASE)
  end

  local socket_err = self:_close_session(pg)
  if socket_err then
    return nil, socket_err
  end
  if results and type(results) == 'table' then
    for i, row in ipairs(results) do
      results[i] = self:_unmarshall(row)
    end
  end
  return results, err

end

-- Execute a sql query.
-- @param `query`        The query to execute
-- @return :_execute()
function BaseDao:execute(query)

  -- Execute statement
  local results, err = self:_execute(query)

  return results, err
end

-- Insert a row in the DAO's table.
-- Perform schema validation, UNIQUE checks, FOREIGN checks.
-- @param `t`       A table representing the entity to insert
-- @return `result` Inserted entity or nil
-- @return `error`  Error if any during the execution
function BaseDao:insert(t)
  assert(t ~= nil, "Cannot insert a nil element")
  assert(type(t) == "table", "Entity to insert must be a table")

  local ok, errors, self_err

  -- Populate the entity with any default/overriden values and validate it
  ok, errors, self_err = validations.validate_entity(t, self._schema, {
    dao = self._factory,
    dao_insert = function(field)

      if field.type == "id" then
        return uuid()
      -- default handled in postgres
      -- otherwise explicility set a timestamp
      -- elseif field.type == "timestamp" then
      --   return os.date("!%c")
      end
    end
  })

  if self_err then
    return nil, self_err
  elseif not ok then
    return nil, DaoError(errors, error_types.SCHEMA)
  end

  local insert_q = query_builder.insert(self._table, self:_marshall(t))
  local _, query_err = self:execute(insert_q)
  if query_err then
    return nil, query_err
  else
    return self:_unmarshall(t)
  end
end

local function extract_primary_key(t, primary_key, clustering_key)
  local t_no_primary_key = utils.deep_copy(t)
  local t_primary_key  = {}
  for _, key in ipairs(primary_key) do
    t_primary_key[key] = t[key]
    t_no_primary_key[key] = nil
  end
  if clustering_key then
    for _, key in ipairs(clustering_key) do
      t_primary_key[key] = t[key]
      t_no_primary_key[key] = nil
    end
  end
  return t_primary_key, t_no_primary_key
end

-- When updating a row that has a json-as-text column (ex: plugin_configuration.value),
-- we want to avoid overriding it with a partial value.
-- Ex: value.key_name + value.hide_credential, if we update only one field,
-- the other should be preserved. Of course this only applies in partial update.
local function fix_tables(t, old_t, schema)
  for k, v in pairs(schema.fields) do
    if t[k] ~= nil and v.schema then
      local s = type(v.schema) == "function" and v.schema(t) or v.schema
      for s_k, s_v in pairs(s.fields) do
        if not t[k][s_k] and old_t[k] then
          t[k][s_k] = old_t[k][s_k]
        end
      end
      fix_tables(t[k], old_t[k], s)
    end
  end
end

-- Update a row: find the row with the given PRIMARY KEY and update the other values
-- If `full`, sets to NULL values that are not included in the schema.
-- Performs schema validation, UNIQUE and FOREIGN checks.
-- @param `t`       A table representing the entity to insert
-- @param `full`    If `true`, set to NULL any column not in the `t` parameter
-- @return `result` Updated entity or nil
-- @return `error`  Error if any during the execution
function BaseDao:update(t, full)
  assert(t ~= nil, "Cannot update a nil element")
  assert(type(t) == "table", "Entity to update must be a table")

  local ok, errors, self_err

  -- Check if exists to prevent upsert
  local res, err = self:find_by_primary_key(t)
  if err then
    return false, err
  elseif not res then
    return false
  end

  if not full then
    fix_tables(t, res, self._schema)
  end

  -- Validate schema
  ok, errors, self_err = validations.validate_entity(t, self._schema, {
    partial_update = not full,
    full_update = full,
    dao = self._factory
  })
  if self_err then
    return nil, self_err
  elseif not ok then
    return nil, DaoError(errors, error_types.SCHEMA)
  end

  -- Extract primary key from the entity
  local t_primary_key, t_no_primary_key = extract_primary_key(t, self._primary_key, self._clustering_key)

  -- If full, add `null` values to the SET part of the query for nil columns
  if full then
    for k, v in pairs(self._schema.fields) do
      if not t[k] and not v.immutable then
        t_no_primary_key[k] = dbnull
      end
    end
  end

  local update_q, columns = query_builder.update(self._table, self:_marshall(t_no_primary_key), t_primary_key)

  local _, stmt_err = self:execute(update_q, columns, self:_marshall(t))
  if stmt_err then
    return nil, stmt_err
  else
    return self:_unmarshall(t)
  end
end

-- Retrieve a row at given PRIMARY KEY.
-- @param  `where_t` A table containing the PRIMARY KEY (columns/values) of the row to retrieve.
-- @return `row`   The first row of the result.
-- @return `error`
function BaseDao:find_by_primary_key(where_t)
  assert(self._primary_key ~= nil and type(self._primary_key) == "table" , "Entity does not have a primary_key")
  assert(where_t ~= nil and type(where_t) == "table", "where_t must be a table")

  local t_primary_key = extract_primary_key(where_t, self._primary_key)

  if next(t_primary_key) == nil then
    return nil
  end

  local select_q, where_columns = query_builder.select(self._table, t_primary_key, nil)
  local data, err = self:execute(select_q, where_columns, t_primary_key)

  -- Return the 1st and only element of the result set
  if data and utils.table_size(data) > 0 then
    data = table.remove(data, 1)
  else
    data = nil
  end

  return data, err
end

-- Retrieve a set of rows from the given columns/value table.
-- @param `where_t`      (Optional) columns/values table by which to find an entity.
-- @param `page_size`    Size of the page to retrieve (number of rows).
-- @param `paging_state` Start page from given offset. See lua-resty-postgres's :execute() option.
-- @return `res`
-- @return `err`
function BaseDao:find_by_keys(where_t, page_size, paging_state)
  local select_q = query_builder.select(self._table, where_t, nil, {
    page_size = page_size,
    paging_state = paging_state
  })
  local res = self:execute(select_q)
  return res
end

-- Retrieve a page of the table attached to the DAO.
-- @param  `page_size`    Size of the page to retrieve (number of rows).
-- @param  `paging_state` Start page from given offset. See lua-resty-postgres's :execute() option.
-- @return `find_by_keys()`
function BaseDao:find(page_size, paging_state)
  return self:find_by_keys(nil, page_size, paging_state)
end

-- Delete the row at a given PRIMARY KEY.
-- @param  `where_t` A table containing the PRIMARY KEY (columns/values) of the row to delete
-- @return `success` True if deleted, false if otherwise or not found
-- @return `error`   Error if any during the query execution
function BaseDao:delete(where_t)
  assert(self._primary_key ~= nil and type(self._primary_key) == "table" , "Entity does not have a primary_key")
  assert(where_t ~= nil and type(where_t) == "table", "where_t must be a table")

  -- don't need to test if exists first, this was necessary in cassandra?

  local t_primary_key = extract_primary_key(where_t, self._primary_key, self._clustering_key)
  local delete_q, where_columns = query_builder.delete(self._table, t_primary_key)
  local rows = self:execute(delete_q, where_columns, where_t)

  -- did we delete anything
  return rows.affected_rows > 0
end

-- Truncate the table of this DAO
-- @return `:execute()`
function BaseDao:drop()
  local truncate_q = query_builder.truncate(self._table)
  return self:execute(truncate_q)
end

return BaseDao
