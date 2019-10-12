local upload = require "resty.upload"
local json = require "cjson"
local chunk_size = 4096

local response = {}
response["returnCode"]=-1
response["describeMsg"] = ""
response['data']= {}
response['data']['url']={}

local form, err = upload:new(chunk_size)
if not form then
    response["describeMsg"] = "未检测到文件上传" .. err
    ngx.say(json.encode(response))
    return 
end
form:set_timeout(1000)
-- 字符串 split 分割
string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end
-- 支持字符串前后 trim
string.trim = function(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
-- 文件保存的根路径
-- local saveRootPath = ngx.var.store_dir .. os.date("/%Y%m/%d/", os.time()+3600*8)
local uppath = os.date("/%Y%m/%d/", os.time()+3600*8)
local saveRootPath = "/data/openresty/html/upload" .. uppath
local urlbase = 'http://img.abc.cn/upload'

-- 判断文件夹是否存在，不存在则自动创建
local file=io.open(saveRootPath, "rb")
if file then
        file:close()
else
        local ok,err = os.execute("mkdir -p " .. saveRootPath)
        if not ok then
		response["describeMsg"] = "创建上传目录失败,路径为:" .. saveRootPath
		ngx.say(json.encode(response))
		return
        end
end


-- 临时文件
local tmpname = os.tmpname()

-- 保存的文件对象
local fileToSave
--文件是否成功保存
local ret_save = false
local ext = ''

local i = 1
while true do
    local typ, res, err = form:read()
    if not typ then
	response["describeMsg"] = "failed to read: " .. err
	ngx.say(json.encode(response))
	return
    end
    if typ == "header" then
        -- 开始读取 http header
        -- 解析出本次上传的文件名
        local key = res[1]
        local value = res[2]
        if key == "Content-Disposition" then
            -- 解析出本次上传的文件名
            -- form-data; name="testFileName"; filename="testfile.txt"
            local kvlist = string.split(value, ';')
            for _, kv in ipairs(kvlist) do
                local seg = string.trim(kv)
                if seg:find("filename") then
                    local kvfile = string.split(seg, "=")
                    local filename = string.sub(kvfile[2], 2, -2)
		    ext = filename:match(".+%.(%w+)$")
		    -- 判断文件类型
                    if string.lower(ext) ~= 'jpg' and string.lower(ext) ~= 'jpeg' and string.lower(ext) ~= 'png' and string.lower(ext) ~= 'bmp' and string.lower(ext) ~= 'zip' and string.lower(ext) ~= 'mp4' and string.lower(ext) ~= 'flv' and string.lower(ext) ~= 'avi' and string.lower(ext) ~= 'mkv' then
			response["describeMsg"] = "不允许该文件类型"
			ngx.say(json.encode(response))
			return
                    end
                    if filename then
                        fileToSave = io.open(tmpname, "w+")
                        if not fileToSave then
				response["describeMsg"] = "创建临时文件失败"
				ngx.say(json.encode(response))
				return
                        end
                        break
                    end
                end
            end
        end
    elseif typ == "body" then
        -- 开始读取 http body
        if fileToSave then
            fileToSave:write(res)
        end
    elseif typ == "part_end" then
        -- 文件写结束，关闭文件
        if fileToSave then
            fileToSave:close()
            fileToSave = nil
        end
	local f=io.open(tmpname,"rb")
	local nfile=ngx.md5(f:read("*a")) .. '.' .. ext
	f:close()
	local ok,err = os.execute("mv " .. tmpname .. " " .. saveRootPath .. '/' .. nfile)
	if not ok then
		ngx.say("file can not write")
		response["describeMsg"] = "文件移动失败"
		ngx.say(json.encode(response))
		return 
	else
		response['data']['url'][i]=urlbase .. uppath  .. nfile
		response["returnCode"]=0
		response["describeMsg"] = "文件上传成功"
		i = i + 1
	end
	
        ret_save = true
    elseif typ == "eof" then
        -- 文件读取结束
        break
    else
        ngx.log(ngx.INFO, "do other things")
    end
end
if ret_save then
    ngx.say(json.encode(response))
end

