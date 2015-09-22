local _ = require "spec.spec_helpers"

describe("dao", function()
  it("should load a dao as configured", function()
    local dao = require "kong.dao".BaseDao
    assert.truthy(dao)
    assert.truthy(dao.update)
    assert.truthy(dao.insert)
    assert.truthy(dao.find_by_keys)
  end)
end)