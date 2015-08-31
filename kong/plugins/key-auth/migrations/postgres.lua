local Migrations = {
  {
    name = "m2015-07-31-172400_init_keyauth",
    up = function(options)
      return [[
        CREATE TABLE IF NOT EXISTS keyauth_credentials(
          id uuid,
          consumer_id uuid REFERENCES consumers (id) ON DELETE CASCADE,
          key text,
          created_at timestamp without time zone default (now() at time zone 'utc'),
          PRIMARY KEY (id)
        );

        DO $$
        BEGIN
        IF (
          SELECT to_regclass('public.keyauth_key_idx')
            ) IS NULL THEN
          CREATE INDEX keyauth_key_idx ON keyauth_credentials(key);
        END IF;

        IF (
          SELECT to_regclass('public.keyauth_consumer_idx')
            ) IS NULL THEN
          CREATE INDEX keyauth_consumer_idx ON keyauth_credentials(consumer_id);
        END IF;
        END$$;

      ]]
    end,
    down = function(options)
      return [[
        DROP TABLE keyauth_credentials;
      ]]
    end
  }
}

return Migrations
