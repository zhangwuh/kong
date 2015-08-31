local PostgresFactory = require "kong.dao.postgres.factory"
local spec_helper = require "spec.spec_helpers"

local env = spec_helper.get_env() -- test environment
local configuration = env.configuration
configuration.postgres = configuration.databases_available[configuration.database].properties

describe(":prepare()", function()

  it("should return an error if cannot connect to Postgres", function()
    local new_factory = PostgresFactory({ hosts = "127.0.0.1",
                                           port = 456789,
                                           database = configuration.postgres.database
    })
    local err = new_factory:execute_queries('select * from schema_migrations')
    assert.truthy(err)
    assert.True(err.database)
    assert.are.same("Cassandra error: connection refused", err.message)
  end)

end)
