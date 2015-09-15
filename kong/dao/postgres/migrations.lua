local BaseDao = require "kong.dao.postgres.base_dao"

local Migrations = BaseDao:extend()

function Migrations:new(properties)
  self._table = "schema_migrations"
  self.queries = {
    add_migration = [[
      UPDATE schema_migrations SET migrations = array_append(migrations, '%s') where id = '%s'
    ]],
    get_all_migrations = [[
      SELECT * FROM schema_migrations;
    ]],
    insert_migrations = "INSERT INTO schema_migrations (id,migrations) VALUES ('%s', '{}')",
    get_all_migrations = "SELECT id,migrations FROM schema_migrations",
    get_migrations = "SELECT id,migrations FROM schema_migrations where id = '%s'",
    delete_migration = "UPDATE schema_migrations SET migrations = array_remove(migrations, '%s') WHERE id = '%s'",
    get_migrations_table = "SELECT to_regclass('public.schema_migrations')",
    reset_all_tables = [[
      drop schema public cascade;
      create schema public;
    ]]
  }

  Migrations.super.new(self, properties)
end

-- Log (add) given migration to schema_migrations table.
-- @param migration_name Name of the migration to log
-- @return query result
-- @return error if any
function Migrations:add_migration(migration_name, identifier)
  -- if identifier row doesn't exist insert it first
  local rows
  rows = Migrations.super._execute(self, string.format(self.queries.get_migrations, identifier))
  if #rows == 0 then
    Migrations.super._execute(self, string.format(self.queries.insert_migrations, identifier))
  end

  return Migrations.super._execute(self,
    string.format(self.queries.add_migration, migration_name, identifier))
end

-- Return all logged migrations if any. Check if keyspace exists before to avoid error during the first migration.
-- @return A list of previously executed migration (as strings)
-- @return error if any
function Migrations:get_migrations(identifier)
  local rows

  rows = Migrations.super._execute(self, self.queries.get_migrations_table)

  if not rows then
    return nil, "Error getting table"
  elseif not rows[1]["to_regclass"] then
    -- table is not yet created, this is the first migration
    return nil
  end

  if identifier ~= nil then
    rows = Migrations.super._execute(self, string.format(self.queries.get_migrations, identifier))
  else
    rows = Migrations.super._execute(self, self.queries.get_all_migrations)
  end

  if not rows then
    return nil, "Error getting migrations"
  elseif rows and #rows > 0 then
    return identifier == nil and rows or rows[1].migrations
  end
end

-- Unlog (delete) given migration from the schema_migrations table.
-- @return query result
-- @return error if any
function Migrations:delete_migration(migration_name, identifier)
  return Migrations.super._execute(self, string.format(self.queries.delete_migration, migration_name, identifier))
end

function Migrations:drop_keyspace(database)
  -- can't drop db so drop tables
  return Migrations.super._execute(self, self.queries.reset_all_tables)
end
return { migrations = Migrations }