local spec_helper = require "spec.spec_helpers"

describe("dao", function()
  it("should load a dao as configured", function()
    local dao = require "kong.dao".BaseDao
    assert.truthy(dao)
    assert.truthy(dao.prepare_stmt)
  end)
end)