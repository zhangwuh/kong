local spec_helper = require "spec.spec_helpers"
local pgmoon = require "pgmoon"
local constants = require "kong.constants"
local DaoError = require "kong.dao.error"
local utils = require "kong.tools.utils"
local cjson = require "cjson"
local uuid = require "uuid"

-- Raw session for double-check purposes
local session
-- Load everything we need from the spec_helper
local env = spec_helper.get_env() -- test environment
local faker = env.faker
local dao_factory = env.dao_factory
local configuration = env.configuration
configuration.postgres = configuration.databases_available[configuration.database].properties

-- An utility function to apply tests on core collections.
local function describe_core_collections(tests_cb)
  for type, dao in pairs({ api = dao_factory.apis,
                           consumer = dao_factory.consumers }) do
    local collection = type == "plugin" and "plugins" or type.."s"
    describe(collection, function()
      tests_cb(type, collection)
    end)
  end
end

-- An utility function to test if an object is a DaoError.
-- Naming is due to luassert extensibility's restrictions
local function daoError(state, arguments)
  local stub_err = DaoError("", "")
  return getmetatable(stub_err) == getmetatable(arguments[1])
end

local say = require("say")
say:set("assertion.daoError.positive", "Expected %s\nto be a DaoError")
say:set("assertion.daoError.negative", "Expected %s\nto not be a DaoError")
assert:register("assertion", "daoError", daoError, "assertion.daoError.positive", "assertion.daoError.negative")

-- Let's go
describe("Postgres", function()

  setup(function()

    spec_helper.prepare_db()

    -- Create a parallel session to verify the dao's behaviour
    session = pgmoon.new({
      host =  configuration.postgres.hosts,
      port = configuration.postgres.port,
      database = configuration.postgres.keyspace,
      user = "postgres"
    })

    local _, err = session:connect()
    assert.falsy(err)

  end)

  teardown(function()
    -- tear down everything!
    local rows, num_queries = session:query([[drop schema public cascade; create schema public;]])
    if num_queries < 2 then
      error("couldn't drop tables")
    end
    if session then
      local _, err = session:disconnect()
      assert.falsy(err)
    end
  end)

  describe("Base DAO", function()

    describe(":insert()", function()

      it("should error if called with invalid parameters", function()
        assert.has_error(function()
          dao_factory.apis:insert()
        end, "Cannot insert a nil element")

        assert.has_error(function()
          dao_factory.apis:insert("")
        end, "Entity to insert must be a table")
      end)

      it("should insert in DB and let the schema validation add generated values", function()
        -- API
        local api_t = faker:fake_entity("api")

        local api, err = dao_factory.apis:insert(api_t)
        assert.falsy(err)
        assert.truthy(api.id)
        local apis, rows = session:query("SELECT * FROM \"apis\"")
        assert.falsy(not apis)
        assert.True(#apis > 0)
        assert.equal(api.id, apis[1].id)
        -- verify date was set by postgres
        assert.truthy(apis[1].created_at)

        -- API
        api, err = dao_factory.apis:insert {
          inbound_dns = "test.com",
          upstream_url = "http://mockbin.com"
        }
        assert.falsy(err)
        assert.truthy(api.name)
        assert.equal("test.com", api.name)

        -- Consumer
        local consumer_t = faker:fake_entity("consumer")
        local consumer, err = dao_factory.consumers:insert(consumer_t)
        assert.falsy(err)
        assert.truthy(consumer.id)

        local consumers, err = session:query("SELECT * FROM consumers")
        assert.True(#consumers > 0)
        assert.equal(consumer.id, consumers[1].id)
        assert.truthy(consumers[1].created_at)

        -- Plugin configuration
        local plugin_t = {name = "key-auth", api_id = api.id, consumer_id = nil}
        local plugin, err = dao_factory.plugins:insert(plugin_t)
        assert.falsy(err)
        assert.truthy(plugin)
        local plugins, err = session:query("SELECT * FROM plugins")
        assert.True(#plugins > 0)
        assert.equal(plugin.id, plugins[1].id)
      end)

      it("should let the schema validation return errors and not insert", function()
        -- Without an api_id, it's a schema error
        local plugin_t = faker:fake_entity("plugin")
        local plugin, err = dao_factory.plugins:insert(plugin_t)
        assert.falsy(plugin)
        assert.truthy(err)
        assert.is_daoError(err)
        assert.True(err.schema)
        assert.are.same("api_id is required", err.message.api_id)
      end)

      it("should ensure fields with `unique` are unique", function()
        local api_t = faker:fake_entity("api")

        -- Success
        local _, err = dao_factory.apis:insert(api_t)
        assert.falsy(err)

        -- Failure
        local api, err = dao_factory.apis:insert(api_t)
        assert.truthy(err)
        assert.is_daoError(err)
--        assert.True(err.unique)
        assert.truthy(string.find(err.message,'duplicate key value violates unique constraint "apis_name_key"'))
        assert.falsy(api)
      end)

      it("should throw errors for foreign key constraints", function()
        -- Plugin configuration
        local plugin_t = faker:fake_entity("plugin")
        plugin_t.api_id = uuid()

        local plugin, err = dao_factory.plugins:insert(plugin_t)
        assert.falsy(plugin)
        assert.truthy(err)
        assert.is_daoError(err)
        --assert.True(err.foreign)
        assert.truthy(err.message, "violates foreign key constraint")
      end)

      it("should do insert checks for entities with `self_check`", function()
        local api, err = dao_factory.apis:insert(faker:fake_entity("api"))
        assert.falsy(err)
        assert.truthy(api.id)

        local plugin_t = faker:fake_entity("plugin")
        plugin_t.api_id = api.id

        -- Success: plugin doesn't exist yet
        local plugin, err = dao_factory.plugins:insert(plugin_t)
        assert.falsy(err)
        assert.truthy(plugin)

        -- Failure: the same plugin is already inserted
        local plugin, err = dao_factory.plugins:insert(plugin_t)
        assert.falsy(plugin)
        assert.truthy(err)
        assert.is_daoError(err)
        assert.True(err.unique)
        assert.are.same("Plugin configuration already exists", err.message)
      end)
    end)
  end)
end) -- describe postgres

