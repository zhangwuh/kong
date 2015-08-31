local DAO = require "kong.dao.postgres.factory"
local pgmoon = require "pgmoon"
local Migrations = require "kong.tools.migrations"
local spec_helper = require "spec.spec_helpers"

--
-- Stubs, instanciation and custom assertions
--

local TEST_DATABASE = "kong_tests"
local PLUGIN_MIGRATIONS_STUB = require "spec.integration.dao.postgres.fixtures.migrations.postgres"
local CORE_MIGRATIONS_STUB = {
  {
    name = "stub_skeleton",
    init = true,
    up = function(options)
      return [[
        CREATE TABLE IF NOT EXISTS schema_migrations(
          id text PRIMARY KEY,
          migrations varchar(100)[]
        );
      ]]
    end,
    down = function(options)
      return [[
        drop table schema_migrations;
      ]]
    end
  },
  {
    name = "stub_mig1",
    up = function()
      return [[
        CREATE TABLE users(
          id uuid,
          name text,
          age int,
          PRIMARY KEY (id)
        );
      ]]
    end,
    down = function()
       return [[
         DROP TABLE users;
       ]]
    end
  },
  {
    name = "stub_mig2",
    up = function()
      return [[
        CREATE TABLE users2(
          id uuid,
          name text,
          age int,
          PRIMARY KEY (id)
        );
      ]]
    end,
    down = function()
       return [[
         DROP TABLE users2;
       ]]
    end
  }

}

local test_env = spec_helper.get_env() -- test environment
local test_configuration = test_env.configuration
local test_postgres_properties = test_configuration.databases_available[test_configuration.database].properties
test_postgres_properties.database = TEST_DATABASE

local test_dao = DAO(test_postgres_properties)
local pg = pgmoon.new({
  host = test_postgres_properties.hosts,
  port = test_postgres_properties.port,
  database = test_postgres_properties.database,
  user = test_postgres_properties.username
})

local function has_table(state, arguments)
  local rows = pg:query("SELECT to_regclass('public.schema_migrations')")
  if not rows or #rows < 1 then
    error('schema_migrations doesn\'t exist')
  end

  local identifier = arguments[1]

  local found = false
  rows = pg:query("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';")
  for _, table in ipairs(rows) do
    if table.table_name == arguments[1] then
      return true
    end
  end

  return found
end

local say = require "say"
say:set("assertion.has_table.positive", "Expected keyspace to have table %s")
say:set("assertion.has_table.negative", "Expected keyspace not to have table %s")
assert:register("assertion", "has_table", has_table, "assertion.has_table.positive", "assertion.has_table.negative")

local function has_migration(state, arguments)
  local identifier = arguments[1]
  local migration = arguments[2]

  local rows, err = test_dao.migrations:get_migrations()
  if err then
    error(err)
  end

  for _, record in ipairs(rows) do
    if record.id == identifier then
      for _, migration_record in ipairs(record.migrations) do
        if migration_record == migration then
          return true
        end
      end
    end
  end

  return false
end

local say = require "say"
say:set("assertion.has_migration.positive", "Expected keyspace to have migration %s record")
say:set("assertion.has_migration.negative", "Expected keyspace not to have migration %s recorded")
assert:register("assertion", "has_migration", has_migration, "assertion.has_migration.positive", "assertion.has_migration.negative")

--
-- Migrations test suite
--

describe("Migrations", function()
  local migrations

  setup(function()
    local ok, err = pg:connect()
    if not ok then
      error(err)
    end
  end)

  teardown(function()
    local rows, num_queries = pg:query([[drop schema public cascade; create schema public;]])
    if num_queries < 2 then
      error("couldn't drop tables")
    end
  end)

  it("should be instanciable", function()
    migrations = Migrations(test_dao, CORE_MIGRATIONS_STUB, "spec.integration.dao.postgres")
    assert.truthy(migrations)
    assert.same(CORE_MIGRATIONS_STUB, migrations.core_migrations)
  end)

  describe("migrate", function()
    it("should run core migrations", function()
      local cb = function(identifier, migration) end
      local s = spy.new(cb)

      local err = migrations:migrate("core", s)
      assert.falsy(err)

      assert.spy(s).was_called(3)
      assert.spy(s).was_called_with("core", CORE_MIGRATIONS_STUB[1])
      assert.spy(s).was_called_with("core", CORE_MIGRATIONS_STUB[2])
      assert.spy(s).was_called_with("core", CORE_MIGRATIONS_STUB[3])

      assert.has_table("users2")
      assert.has_migration("core", "stub_mig2")
    end)
    it("should run plugins migrations", function()
      local cb = function(identifier, migration) end
      local s = spy.new(cb)

      local err = migrations:migrate("fixtures", s)
      assert.falsy(err)

      assert.spy(s).was_called(2)
      assert.spy(s).was_called_with("fixtures", PLUGIN_MIGRATIONS_STUB[1])
      assert.spy(s).was_called_with("fixtures", PLUGIN_MIGRATIONS_STUB[2])

      assert.has_table("plugins2")
      assert.has_migration("fixtures", "stub_fixture_mig2")
    end)
  end)
  describe("rollback", function()
    it("should rollback core migrations", function()
      local rollbacked, err = migrations:rollback("core")
      assert.falsy(err)
      assert.equal("stub_mig2", rollbacked.name)
      assert.not_has_migration("core", "stub_mig2")
      assert.not_has_table("users2")
      assert.has_migration("core", "stub_mig1")
      assert.has_table("users")
    end)
    it("should rollback plugins migrations", function()
      local rollbacked, err = migrations:rollback("fixtures")
      assert.falsy(err)
      assert.equal("stub_fixture_mig2", rollbacked.name)
      assert.not_has_migration("fixtures", "stub_fixture_mig2")
      assert.not_has_table("plugins2")
      assert.has_migration("fixtures", "stub_fixture_mig1")
      assert.has_table("plugins")
    end)
  end)
  describe("migrate bis", function()
    it("should migrate core from the last record", function()
      local cb = function(identifier, migration) end
      local s = spy.new(cb)

      local err = migrations:migrate("core", s)
      assert.falsy(err)

      assert.spy(s).was_called(1)
      assert.spy(s).was_called_with("core", CORE_MIGRATIONS_STUB[3])

      assert.has_table("users2")
      assert.has_migration("core", "stub_mig2")
    end)
    it("should migrate plugins from the last record", function()
      local cb = function(identifier, migration) end
      local s = spy.new(cb)

      local err = migrations:migrate("fixtures", s)
      assert.falsy(err)

      assert.spy(s).was_called(1)
      assert.spy(s).was_called_with("fixtures", PLUGIN_MIGRATIONS_STUB[2])

      assert.has_table("plugins2")
      assert.has_migration("fixtures", "stub_fixture_mig2")
   end)
  end)
end)
