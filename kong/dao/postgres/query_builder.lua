local _M = {}
local constants = require "kong.constants"
local pgmoon = require "pgmoon"
local pg = pgmoon.new({});

local function escape_literal(s)
  return pg:escape_literal(s)
end

local function escape_identifier(s)
  return pg:escape_identifier(s)
end

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function select_fragment(table_name, select_columns)
  if select_columns then
    assert(type(select_columns) == "table", "select_columns must be a table")
    select_columns = table.concat(select_columns, ", ")
  else
    select_columns = "*"
  end

  return string.format("SELECT %s FROM %s", select_columns, escape_identifier(table_name))
end

local function insert_fragment(table_name, insert_values)
  local values, columns = {}, {}
  for column, value in pairs(insert_values) do
    table.insert(values, escape_literal(value))
    table.insert(columns, escape_identifier(column))
  end

  local columns_names_str = table.concat(columns, ", ")
  local values_str = table.concat(values, ", ")

  return string.format("INSERT INTO %s(%s) VALUES(%s)", escape_identifier(table_name), columns_names_str, values_str)
end

local function update_fragment(table_name, update_values)
  local values, update_columns = {}, {}
  for column, value in pairs(update_values) do
    table.insert(update_columns, escape_identifier(column))
    table.insert(values, string.format("%s = %s", escape_identifier(column), escape_literal(value)))
  end

  values = table.concat(values, ", ")

  return string.format("UPDATE %s SET %s", escape_identifier(table_name), values)
end

local function delete_fragment(table_name)
  return string.format("DELETE FROM %s", escape_identifier(table_name))
end

local function where_fragment(where_t, no_filtering_check)
  if not where_t then where_t = {} end

  assert(type(where_t) == "table", "where_t must be a table")
  if next(where_t) == nil then
    if not no_filtering_check then
      return ""
    else
      error("where_t must contain keys")
    end
  end

  local where_parts = {}

  for column, value in pairs(where_t) do
    -- don't pass database_null_ids
    if value ~= constants.DATABASE_NULL_ID then
      table.insert(where_parts, string.format("%s = %s", escape_identifier(column), escape_literal(value)))
    end
  end

  where_parts = table.concat(where_parts, " AND ")

  return string.format("WHERE %s", where_parts)
end

-- Generate a SELECT query with an optional WHERE instruction.
-- If building a WHERE instruction, we need some additional informations about the table.
-- @param `table_name`         Name of the table
-- @param `select_columns`        A list of columns to retrieve
-- @return `query`                The SELECT query
function _M.select(table_name, where_t, select_columns)
  assert(type(table_name) == "string", "table_name must be a string")

  local select_str = select_fragment(table_name, select_columns)
  local where_str, columns = where_fragment(where_t)

  return trim(string.format("%s %s", select_str, where_str))
end

-- Generate an INSERT query.
-- @param `table_name` Name of the table
-- @param `insert_values` A columns/values table of values to insert
-- @return `query`                The INSERT query
function _M.insert(table_name, insert_values)
  assert(type(table_name) == "string", "table_name must be a string")
  assert(type(insert_values) == "table", "insert_values must be a table")
  assert(next(insert_values) ~= nil, "insert_values cannot be empty")
  return insert_fragment(table_name, insert_values)
end

-- Generate an UPDATE query with update values (SET part) and a mandatory WHERE instruction.
-- @param `table_name` Name of the table
-- @param `update_values` A columns/values table of values to update
-- @param `where_t`       A columns/values table to select the row to update
-- @return `query`        The UPDATE query
function _M.update(table_name, update_values, where_t)
  assert(type(table_name) == "string", "table_name must be a string")
  assert(type(update_values) == "table", "update_values must be a table")
  assert(next(update_values) ~= nil, "update_values cannot be empty")

  local update_str, update_columns = update_fragment(table_name, update_values)
  local where_str, where_columns = where_fragment(where_t, true)

  -- concat columns from SET and WHERE parts of the query
  local columns = {}
  if update_columns then
    columns = update_columns
  end
  if where_columns then
    for _, v in ipairs(where_columns) do
      table.insert(columns, v)
    end
  end

  return trim(string.format("%s %s", update_str, where_str))
end

-- Generate a DELETE QUERY with a mandatory WHERE instruction.
-- @param `table_name` Name of the table
-- @param `where_t`       A columns/values table to select the row to DELETE
-- @return `columns`      An list of columns to bind for the query, in the order of the placeholder markers (?)
function _M.delete(table_name, where_t)
  assert(type(table_name) == "string", "table_name must be a string")

  local delete_str = delete_fragment(table_name)
  local where_str = where_fragment(where_t, true)

  return trim(string.format("%s %s", delete_str, where_str))
end

-- Generate a TRUNCATE query
-- @param `table_name` Name of the table
-- @return `query`
function _M.truncate(table_name)
  assert(type(table_name) == "string", "table_name must be a string")

  return "TRUNCATE "..escape_identifier(table_name).." CASCADE"
end

return _M

