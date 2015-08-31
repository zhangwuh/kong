local Migrations = {
  -- skeleton
  {
    init = true,
    name = "m2015-01-12-175310_skeleton",
    up = function(options)
      -- TODO: can we create the database as well if we can?
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
  -- init schema migration
  {
    name = "m2015-01-12-175310_init_schema",
    up = function(options)
      return [[
        CREATE TABLE IF NOT EXISTS consumers(
          id uuid,
          custom_id text,
          username text,
          created_at timestamp without time zone default (now() at time zone 'utc'),
          PRIMARY KEY (id)
        );
        DO $$
        BEGIN
        IF (
          SELECT to_regclass('public.custom_id_idx')
            ) IS NULL THEN
          CREATE INDEX custom_id_idx ON consumers (custom_id);
        END IF;
        IF (
          SELECT to_regclass('public.username_idx')
            ) IS NULL THEN
          CREATE INDEX username_idx ON consumers ((lower(username)));
        END IF;
        END$$;
        CREATE TABLE IF NOT EXISTS apis(
          id uuid,
          name text,
          inbound_dns text,
          path text,
          strip_path boolean,
          upstream_url text,
          preserve_host boolean,
          created_at timestamp without time zone default (now() at time zone 'utc'),
          PRIMARY KEY (id),
          UNIQUE(name),
          UNIQUE(inbound_dns),
          UNIQUE(path)
        );
        DO $$
        BEGIN
        IF (
          SELECT to_regclass('public.apis_name_idx')
            ) IS NULL THEN
          CREATE INDEX apis_name_idx ON apis(name);
        END IF;
        IF (
          SELECT to_regclass('public.apis_dns_idx')
            ) IS NULL THEN
          CREATE INDEX apis_dns_idx ON apis(inbound_dns);
        END IF;
        IF (
          SELECT to_regclass('public.apis_path')
            ) IS NULL THEN
          CREATE INDEX apis_path ON apis(path);
        END IF;
        END$$;
        CREATE TABLE IF NOT EXISTS plugins(
          id uuid,
          api_id uuid REFERENCES apis (id) ON DELETE CASCADE,
          consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
          name text,
          config jsonb, -- json plugin data
          enabled boolean,
          created_at timestamp without time zone default (now() at time zone 'utc'),
          PRIMARY KEY (id, name)
        );
        DO $$
        BEGIN
        IF (
          SELECT to_regclass('public.plugins_name_idx')
            ) IS NULL THEN
          CREATE INDEX plugins_name_idx ON plugins(name);
        END IF;
        IF (
          SELECT to_regclass('public.plugins_api_idx')
            ) IS NULL THEN
          CREATE INDEX plugins_api_idx ON plugins(api_id);
        END IF;
        IF (
          SELECT to_regclass('public.plugins_consumer_idx')
            ) IS NULL THEN
          CREATE INDEX plugins_consumer_idx ON plugins(consumer_id);
        END IF;
        END$$;
      ]]
    end,
    down = function(options)
      return [[
        DROP TABLE consumers;
        DROP TABLE apis;
        DROP TABLE plugins;
      ]]
    end
  }
}

return Migrations
