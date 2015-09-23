## postgres
- pgmoon fails in init_by_lua - it doesn't check context before trying to use ngx.socket.tcp
- pg:keepalive() fails setkeepalive is nil why? we should be in a valid ngx context?
- one test spec for dao's
- travis ci postgres
- rate-limiting plugin - it's pretty cassandra specific
- use db to set defaults with insert with returning
- research other postgres drivers
    - paging?
- write postgres migration scripts for JWT plugin
