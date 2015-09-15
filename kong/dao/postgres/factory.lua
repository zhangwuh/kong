-- Kong's postgres Factory DAO. Entry-point for retrieving DAO objects that allow
-- interations with the database for entities (APIs, Consumers...).
--
-- Also provides helper methods for preparing queries among the DAOs, migrating the
-- database and dropping it.

local constants = require "kong.constants"
local pgmoon = require "pgmoon"
local DaoError = require "kong.dao.error"
local Object = require "classic"
local utils = require "kong.tools.utils"

local PostgresFactory = Object:extend()

-- Shorthand for accessing one of the underlying DAOs
function PostgresFactory:__index(key)
  if key ~= "daos" and self.daos and self.daos[key] then
    return self.daos[key]
  else
    return PostgresFactory[key]
  end
end

-- Instanciate a Postgres Factory and all its DAOs for various entities
-- @param `properties` Postgres properties
function PostgresFactory:new(properties, plugins)
  self._properties = properties
  self.type = "postgres"
  self.daos = {}

  -- Load core entities DAOs
  for _, entity in ipairs({"apis", "consumers", "plugins"}) do
    self:load_daos(require("kong.dao.postgres."..entity))
  end

  -- Load plugins DAOs
  if plugins then
    for _, v in ipairs(plugins) do
      local loaded, plugin_daos_mod = utils.load_module_if_exists("kong.plugins."..v..".daos")
      if loaded then
        if ngx then
          ngx.log(ngx.DEBUG, "Loading DAO for plugin: "..v)
        end
        self:load_daos(plugin_daos_mod)
      elseif ngx then
        ngx.log(ngx.DEBUG, "No DAO loaded for plugin: "..v)
      end
    end
  end
end

function PostgresFactory:load_daos(plugin_daos)
  for name, plugin_dao in pairs(plugin_daos) do
    self.daos[name] = plugin_dao(self._properties)
    self.daos[name]._factory = self
  end
end

function PostgresFactory:drop()
  local err
  for _, dao in pairs(self.daos) do
    err = select(2, dao:drop())
    if err then
      return err
    end
  end
end

-- Execute a string of queries separated by ;
-- Useful for huge DDL operations such as migrations
-- @param {string} queries Semicolon separated string of queries
-- @return {string} error if any
function PostgresFactory:execute_queries(queries)
  local ok, err
  local pg = pgmoon.new({
    host = self._properties.hosts,
    port = self._properties.port,
    database = self._properties.keyspace
  })

  ok, err = pg:connect()
  if not ok then
    return DaoError(err, constants.DATABASE_ERROR_TYPES.DATABASE)
  end

  local _, errorOrRows = pg:query(queries)

  if string.find(errorOrRows, 'ERROR') then
    err = errorOrRows
  end

  if err then
    return DaoError(err, constants.DATABASE_ERROR_TYPES.DATABASE)
  end

  pg:disconnect()
end

return PostgresFactory
