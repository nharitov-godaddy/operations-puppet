-- SPDX-License-Identifier: Apache-2.0
-- Decide if a request should be routed to mediawiki on k8s or not.
--
-- See https://wikitech.wikimedia.org/wiki/X-Wikimedia-Debug

-- The JIT compiler is causing severe performance issues:
-- https://phabricator.wikimedia.org/T265625
jit.off(true, true)

local config_read_time = nil
-- Wikis on mw-on-k8s. They will be read from mw-on-k8s.lua.conf
local wikis_on_k8s = {}


-- We're mapping the results from multi-dc.lua as we want to process if we're going to k8s *after*
-- multi-dc has been determined
local onprem_to_k8s_cluster_map = {
  ['appservers-ro.discovery.wmnet'] = {host = 'mw-web-ro.discovery.wmnet', port = 4450},
  ['appservers-rw.discovery.wmnet'] = {host = 'mw-web.discovery.wmnet', port = 4450},
  ['api-ro.discovery.wmnet'] = {host = 'mw-api-ext-ro.discovery.wmnet', port = 4447},
  ['api-rw.discovery.wmnet'] = {host = 'mw-api-ext.discovery.wmnet', port = 4447}
}

-- Read the configuration file and return the resulting table
local function read_config()
  local configfile = ts.get_config_dir() .. "/lua/mw-on-k8s.lua.conf"
  local conf = dofile(configfile)
  if (type(conf) ~= "table") then
      ts.error("mw-on-k8s.lua: invalid config file")
      return {}
  end
  return conf
end

-- Reload the config every 10 seconds.
--
-- In ATS 8, Lua modules are never reloaded, you have to restart the server.
-- In ATS 10, there is documentation to the effect that Lua modules may be
-- reloaded if remap.config was touched. Maybe it just means if the plugin
-- parameters were changed.
--
-- Note that with 256 states, read_config() will receive an average of 25.6
-- calls per second. But it takes <1ms for a small file.
local function reload_config()
  local now = ts.now()
  if config_read_time == nil or now - config_read_time > 10 then
      config_read_time = now
      -- only reload the configuration if it's valid
      local conf = read_config()
      if conf ~= {} then
        wikis_on_k8s = conf
      end
  end
end

local function use_k8s()
  -- For now, we just check by wiki
  local host_raw = ts.client_request.header.Host
  if host_raw == nil then
    return false
  end
  local host = host_raw:lower()
  -- do not force ourselves to spell out the mobile domains.
  if host:match("%.m%.") then
    host = host:gsub("%.m%.", ".")
  end
  reload_config()
  local k8s_load = wikis_on_k8s[host]
  -- if no configuration is available for our hostname, fallback to the default.
  if k8s_load == nil then
    k8s_load = wikis_on_k8s["default"]
  end
  -- If all traffic should go to k8s, don't bother with random seeding
  -- we also check for a boolean value for easing the transition
  if k8s_load == 1 or k8s_load == true then
    return true
  end
  if k8s_load == nil or k8s_load == 0 or k8s_load == false then
    return false
  end
  -- All states start with the same random seed, so let's fix that
  if not random_seeded then
    random_seeded = true
    math.randomseed(ts.http.id())
  end
  return math.random() < k8s_load
end

-- The ATS hook point.
function do_remap()
  local orig_url_host = ts.client_request.get_url_host()
  local k8s_dst = onprem_to_k8s_cluster_map[orig_url_host]
  if k8s_dst ~= nil and use_k8s() then
    ts.client_request.set_url_host(k8s_dst.host)
    ts.client_request.set_url_port(k8s_dst.port)
    return TS_LUA_REMAP_DID_REMAP
  end
  return TS_LUA_REMAP_NO_REMAP
end
