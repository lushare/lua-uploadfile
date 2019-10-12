local json=require 'cjson';

local response = {}
response["returnCode"]=0
response["describeMsg"] = ""
response['data']= {}

local function close_redis(red)
        if not red then
                return
        end
        local pool_max_idle_time = 1000
        local pool_size = 100
        local ok, err = red:set_keepalive(pool_max_idle_time, pool_size)
        if not ok then
		return
        end
end

local redis = require("resty.redis")
local red = redis:new()
red:set_timemout(5)
local ip = "192.168.0.215"
local port = 6379
local ok, err = red:connect(ip, port)
if not ok then
        response["describeMsg"]="connect to redis error"
	ngx.say(json.encode(response))
        return close_redis(red)
end

local request_method=ngx.var.request_method;
if request_method == "GET" then
	response["describeMsg"]="Only allow post"
	ngx.say(json.encode(response))
        return close_redis(red);
end;

local headers=ngx.req.get_headers()
function get_client_ip()
    local ip=headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    return ip
end

ngx.req.read_body();
local body_data=json.decode(ngx.req.get_body_data());
for i,v in ipairs(body_data) do
	body_data[i]["time"]=os.date("%Y/%m/%d %H:%M:%S", os.time()+3600*8)
	body_data[i]["user-agent"]=headers["user-agent"]
	body_data[i]["clientIP"]=get_client_ip()
	body_data[i]["referer"]=headers["referer"]
	ok, err = red:lpush("logstash-vue", json.encode(body_data[i]))
	if not ok then
		response["describeMsg"]="write to redis err",err
		ngx.say(json.encode(response))
        	return close_redis(red)
	end
	-- response["data"][i]=body_data[i]
	
end
close_redis(red)
response["describeMsg"]="success"
response["returnCode"]=10000
ngx.say(json.encode(response))
