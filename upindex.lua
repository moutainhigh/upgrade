--upgrade入口　
local conf = require('interface.init')
local redisconf = conf.Redis
local rediscmd = require('interface.utils.rediscmd')
local ProxyMod = require('interface.proxy')

local log = ngx.log
local ERR = ngx.ERR

local headers = ngx.req.get_headers()
local IP = headers['X_FORWARDED_FOR'] or ngx.var.remote_addr
local CHANNEL = headers['channel']
local VERSION = headers['version']
local PHONE = ngx.var['cookie_SmsNoPwdLoginCookie']
if not (IP and CHANNEL and VERSION and PHONE) then return end

local status,err = rediscmd:hget('upgrade','switch')
if not status then
	return
elseif status == "off" then
	return
end
local proxy,err = rediscmd:hget('upgrade','proxy')
if not proxy then
	return
end

log(ERR,IP..'|'..CHANNEL..'|'..VERSION..'|'..PHONE)

local function StrToTable(str)
    if str == nil or type(str) ~= "string" then
        return
    end
    return loadstring("return " .. str)()
end

function Proxy(option)
	local tproxy = StrToTable(option)
	local field = {}
	if type(tproxy) == 'table' then
		for k,v  in pairs(tproxy) do
			table.insert(field,table.concat({'proxy',v},"_" ))
		end
	else
		table.insert(field,table.concat({'proxy',option},'_'))
	end
	if table.getn(field) == 1 then
		local ok,err = rediscmd:hget('upgrade',field[1])
		if not ok then
			return
		end
		if field[1] == 'proxy_ip' then
			ProxyMod:proxy_ip(ok,IP)
		elseif field[1] == 'proxy_head' then
			ProxyMod:proxy_head(ok,CHANNEL)
		elseif field[1] == 'proxy_phone' then
			ProxyMod:proxy_phone(ok,PHONE)
		elseif field[1] == 'proxy_version' then
			ProxyMod:proxy_version(ok,VERSION)
		else
			return
		end
	else
		local REQINFO = {IP,CHANNEL,VERSION,PHONE}
		ProxyMod:proxy_association(field,REQINFO)
	end
end

Proxy(proxy)