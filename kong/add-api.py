#!/usr/bin/env python
import os
import sys

_PORTS = {
    "api-currency": 9002,
    "api-member": 9003,
    "api-coupon": 9001,
    "api-auth": 9004,
    "api-wechat-payment": 9005
}

_ENVS = {
    "dev": {
        "kong_url": "http://192.168.0.165:8001/",
        "api-ip": "192.168.0.170",
        "ip-white-list": "192.168.0.0/24",
        "apis": {
            "api-currency": {
                "enable_oauth": True,
                "scopes": "api-currency, api-currency/ping",
                "black-apis": "/api/latest",
                "provision-key": "456fc47a-3c46-4b2a-cbe5-e80fe7818451",
                "consumer-name": "api-currency-service-client",
                "client-id": "fc7e4417-f212-4062-c0e9-8776f00cc2c5",
                "client-secret": "d32004b0-dea1-4cb9-cce3-3b4e598397d8",
                "redirect-uri": "http://www.igola.com"
            },
            "api-member": {
                "enable_oauth": True,
                "black-apis": "/api/members",
                "provision-key": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "consumer-name": "api-member-service-client",
                "client-id": "677f058f-8db4-11e5-87a9-34363bcd3dd2",
                "client-secret": "afe0f6f5-8db4-11e5-8177-34363bcd3dd2",
                "redirect-uri": "http://www.igola.com"
            },
            "api-coupon": {
                "enable_oauth": True,
                "provision-key": "69d7446a-8977-492d-c992-cd08887ff4bf",
                "consumer-name": "api-coupon-service-client",
                "client-id": "8de49fd7-2836-4621-c646-006a06b5f03d",
                "client-secret": "2e51e3a6-26ae-4263-c225-96d897f48e25",
                "redirect-uri": "http://www.igola.com"
            },
            "api-auth": {
                "enable_oauth": False
            },
            "api-wechat-payment": {
                "enable_oauth": False,
                "provision-key": "0021c175-8838-4cad-ccef-6284d4080d87",
                "consumer-name": "api-wechat-payment-service-client",
                "client-id": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "client-secret": "430cbc54-a1c1-4d5d-cdfb-b9c0a612a1e2",
                "redirect-uri": "http://www.igola.com"
            }
        }
    },
    "sit": {
        "kong_url": "http://192.168.0.166:8001/",
        "api-ip": "192.168.0.175",
        "ip-white-list": "192.168.0.0/24",
        "apis": {
            "api-currency": {
                "provision-key": "456fc47a-3c46-4b2a-cbe5-e80fe7818451",
                "consumer-name": "api-currency-service-client",
                "client-id": "fc7e4417-f212-4062-c0e9-8776f00cc2c5",
                "client-secret": "d32004b0-dea1-4cb9-cce3-3b4e598397d8",
                "redirect-uri": "http://www.igola.com"
            },
            "api-member": {
                "provision-key": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "consumer-name": "api-member-service-client",
                "client-id": "677f058f-8db4-11e5-87a9-34363bcd3dd2",
                "client-secret": "afe0f6f5-8db4-11e5-8177-34363bcd3dd2",
                "redirect-uri": "http://www.igola.com"
            },
            "api-coupon": {
                "provision-key": "69d7446a-8977-492d-c992-cd08887ff4bf",
                "consumer-name": "api-coupon-service-client",
                "client-id": "8de49fd7-2836-4621-c646-006a06b5f03d",
                "client-secret": "2e51e3a6-26ae-4263-c225-96d897f48e25",
                "redirect-uri": "http://www.igola.com"
            },
            "api-auth": {
            },
            "api-wechat-payment": {
                "provision-key": "0021c175-8838-4cad-ccef-6284d4080d87",
                "consumer-name": "api-wechat-payment-service-client",
                "client-id": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "client-secret": "430cbc54-a1c1-4d5d-cdfb-b9c0a612a1e2",
                "redirect-uri": "http://www.igola.com"
            }
        }
    },
    "prod":
{
        "kong_url": "http://10.10.15.121:8001/",
        "api-ip": "192.168.0.175",
        "ip-white-list": "10.10.12.0/24, 10.10.15.0/24",
        "apis": {
            "api-currency": {
                "provision-key": "456fc47a-3c46-4b2a-cbe5-e80fe7818451",
                "consumer-name": "api-currency-service-client",
                "client-id": "fc7e4417-f212-4062-c0e9-8776f00cc2c5",
                "client-secret": "d32004b0-dea1-4cb9-cce3-3b4e598397d8",
                "redirect-uri": "http://www.igola.com"
            },
            "api-member": {
                "provision-key": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "consumer-name": "api-member-service-client",
                "client-id": "677f058f-8db4-11e5-87a9-34363bcd3dd2",
                "client-secret": "afe0f6f5-8db4-11e5-8177-34363bcd3dd2",
                "redirect-uri": "http://www.igola.com"
            },
            "api-coupon": {
                "provision-key": "69d7446a-8977-492d-c992-cd08887ff4bf",
                "consumer-name": "api-coupon-service-client",
                "client-id": "8de49fd7-2836-4621-c646-006a06b5f03d",
                "client-secret": "2e51e3a6-26ae-4263-c225-96d897f48e25",
                "redirect-uri": "http://www.igola.com"
            },
            "api-auth": {
            },
            "api-wechat-payment": {
                "provision-key": "0021c175-8838-4cad-ccef-6284d4080d87",
                "consumer-name": "api-wechat-payment-service-client",
                "client-id": "ab016211-6aaf-46ee-c686-17a76ab3e9c3",
                "client-secret": "430cbc54-a1c1-4d5d-cdfb-b9c0a612a1e2",
                "redirect-uri": "http://www.igola.com"
            }
        }
    }
}

_URL_ADD_API = "curl -X POST %s --data \"name=%s\" --data \"upstream_url=%s\" --data \"request_path=%s\" --data \"strip_request_path=true\""
_URL_CREATE_CONSUMER_API = "curl -X POST %s --data \"username=%s\" --data \"custom_id=%s\""

def env():
    return sys.argv[1]

def api_ip_for_env(env):
    return _ENVS[env]['api-ip']

def kong_url_for_env(env):
    return _ENVS[env]["kong_url"]

def consumer_name(env, api):
    return prop_for_api(env, api, "consumer-name")

def prop_for_api(env, api, key):
    return _ENVS[env]["apis"][api][key]

def api_upstream_url(env, api):
    return "http://%s:%s" % (api_ip_for_env(env), _PORTS[api])

def api_add_url(env, api):
    return _URL_ADD_API % (kong_url_for_env(env) + 'apis', api, api_upstream_url(env, api), api)

def add_ip_white_list_url(env, api):
    return _URL_ADD_API % (kong_url_for_env(env) + 'apis', api, api_upstream_url(env, api), api)

def create_consumer_url(env, api):
    try:
        cn = consumer_name(env, api)
        return _URL_CREATE_CONSUMER_API % (kong_url_for_env(env) + "consumers", cn, cn)
    except KeyError:
        return None

def join_config(config):
    if not config or len(config) == 0:
        return ""

    return " --data ".join(config)

def add_plugin(env, api, plugin, configs):
    url = "curl -i -X POST %sapis/%s/plugins --data \"name=%s\" --data %s" % (kong_url_for_env(env), api, plugin, join_config(configs))
    kong_call(url)

def add_api(env, api):
    url = api_add_url(env, api)
    kong_call(url)

def create_consumer(env, api):
    url = create_consumer_url(env, api)
    kong_call(url)

def add_ip_white_list_list(env, api):
    try:
        config = ["config.whitelist=" + _ENVS[env]["ip-white-list"]]
        add_plugin(env, api, "ip-restriction", config)
    except KeyError:
        print "Ignore adding ip white list for %s on %s" % (api, env)

def add_api_black_list(env, api):
    try:
        config = ["config.blacklist=" + _ENVS[env]["apis"][api]["black-apis"]]
        add_plugin(env, api, "api-acl", config)
    except KeyError:
        print "Ignore adding api black list for %s on %s" % (api, env)

def scopes(env, api):
    try:
        return prop_for_api(env, api, "scopes")
    except KeyError:
        return api

def add_oauth(env, api):
    try:
        config = ["\"config.mandatory_scope=false\"",
                  "\"config.enable_password_grant=true\"",
                  "\"config.scopes=" + scopes(env, api) + "\"",
                  "\"config.provision_key=" + prop_for_api(env, api, "provision-key") + "\""]
        add_plugin(env, api, "oauth2", config)
    except KeyError:
        print "Ignore adding oauth2 for %s on %s" % (api, env)

def create_oauth2_application(env, api):
    try:
        cn = consumer_name(env, api)
        config = ["\"name=" + cn + "\"",
                "\"client_id=" + prop_for_api(env, api, "client-id") + "\"",
                "\"client_secret=" + prop_for_api(env, api, "client-secret") + "\"",
                  "\"redirect_uri=" + prop_for_api(env, api, "redirect-uri") + "\""]
        url = "curl -i -X POST %sconsumers/%s/oauth2 --data %s" % (kong_url_for_env(env), cn, join_config(config))
        kong_call(url)
    except KeyError:
        print "Ignore create oauth2 application for ", api, " on ", env

def clear_all(evn):
    apis = _ENVS[env]["apis"].keys()
    for api in apis:
        try:
            delete_api_url = "curl -i -X DELETE %sapis/%s" % (kong_url_for_env(env), api)
            kong_call(delete_api_url)
            delete_consumer_url = "curl -i -X DELETE %sconsumers/%s" % (kong_url_for_env(env), consumer_name(env, api))
            kong_call(delete_consumer_url)
        except KeyError:
            continue

def kong_call(url):
    if url:
        print "Call kong with: ", url
        return os.system(url)
    else:
        print "URL is none, ignored"

def add_api(env, api):
    add_url = api_add_url(env, api)
    kong_call(add_url)

def create_consumer(env, api):
    url = create_consumer_url(env, api)
    kong_call(url)

def enable_oauth(env, api):
    try:
        if prop_for_api(env, api, "enable_oauth"):
            create_consumer(env, api)
            add_oauth(env, api)
            create_oauth2_application(env, api)
    except KeyError:
        print "Ignore enabling oauth2 ", api, " on ", env

if __name__ == "__main__":
    env = env()
    if len(sys.argv) == 3 and sys.argv[2] == 'delete':
        clear_all(env)
    else:
        apis = _ENVS[env]['apis']
        for api in apis.keys():
            add_api(env, api)
            add_ip_white_list_list(env, api)
            add_api_black_list(env, api)
            enable_oauth(env, api)
