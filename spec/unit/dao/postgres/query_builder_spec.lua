local builder = require "kong.dao.postgres.query_builder"

describe("Query Builder", function()

  -- don't need this for postgres?
  -- local apis_details = {
  --   primary_key = {"id"},
  --   clustering_key = {"cluster_key"},
  --   indexes = {public_dns = true, name = true}
  -- }

  describe("SELECT", function()

    it("should build a SELECT query", function()
      local q = builder.select("apis")
      assert.equal("SELECT * FROM \"apis\"", q)
    end)

    it("should restrict columns to SELECT", function()
      local q = builder.select("apis", nil, {"name", "id"})
      assert.equal("SELECT name, id FROM \"apis\"", q)
    end)

    describe("WHERE", function()

      it("should return a select statement with one where query", function()
        local q, _ = builder.select("apis", {name="mockbin"})
        assert.equal("SELECT * FROM \"apis\" WHERE \"name\" = 'mockbin'", q)
      end)

      it("should return a select statement with more than one statement in the where query", function()
        local q, _ = builder.select("apis", {id="1", name="mockbin"})
        assert.equal("SELECT * FROM \"apis\" WHERE \"id\" = '1' AND \"name\" = 'mockbin'", q)
      end)

    end)

    it("should throw an error if no table_name", function()
      assert.has_error(function()
        builder.select()
      end, "table_name must be a string")
    end)

    it("should throw an error if select_columns is not a table", function()
      assert.has_error(function()
        builder.select("apis", {name="mockbin"}, "")
      end, "select_columns must be a table")
    end)

    it("should throw an error if where_key is not a table", function()
      assert.has_error(function()
        builder.select("apis", "")
      end, "where_t must be a table")
    end)

  end)

  describe("INSERT", function()

    it("should build an INSERT query", function()
      local q = builder.insert("apis", {id="123", name="mockbin"})
      assert.equal("INSERT INTO \"apis\"(\"id\", \"name\") VALUES('123', 'mockbin')", q)
    end)

    it("should throw an error if no table_name", function()
      assert.has_error(function()
        builder.insert(nil, {"id", "name"})
      end, "table_name must be a string")
    end)

    it("should throw an error if no insert_values", function()
      assert.has_error(function()
        builder.insert("apis")
      end, "insert_values must be a table")
    end)

  end)

  describe("UPDATE", function()

    it("should build an UPDATE query", function()
      local q = builder.update("apis", {name="mockbin"}, {id="1"})
      assert.equal("UPDATE \"apis\" SET \"name\" = 'mockbin' WHERE \"id\" = '1'", q)
    end)

    it("should throw an error if no table_name", function()
      assert.has_error(function()
        builder.update()
      end, "table_name must be a string")
    end)

    it("should throw an error if no update_values", function()
      assert.has_error(function()
        builder.update("apis")
      end, "update_values must be a table")

      assert.has_error(function()
        builder.update("apis", {})
      end, "update_values cannot be empty")
    end)

    it("should throw an error if no where_t", function()
      assert.has_error(function()
        builder.update("apis", {name="foo"}, {})
      end, "where_t must contain keys")
    end)

  end)

  describe("DELETE", function()

    it("should build a DELETE query", function()
      local q = builder.delete("apis", {id="1234"})
      assert.equal("DELETE FROM \"apis\" WHERE \"id\" = '1234'", q)
    end)

    it("should throw an error if no table_name", function()
      assert.has_error(function()
        builder.delete()
      end, "table_name must be a string")
    end)

    it("should throw an error if no where_t", function()
      assert.has_error(function()
        builder.delete("apis", {})
      end, "where_t must contain keys")
    end)

  end)

  describe("TRUNCATE", function()

    it("should build a TRUNCATE query", function()
      local q = builder.truncate("apis")
      assert.equal("TRUNCATE \"apis\" CASCADE", q)
    end)

    it("should throw an error if no table_name", function()
      assert.has_error(function()
        builder.truncate()
      end, "table_name must be a string")
    end)

  end)
end)

