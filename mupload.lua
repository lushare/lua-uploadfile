local json = require "cjson"
local response = {}
response["returnCode"]=-1
response["describeMsg"] = ""
response['data']= {}

string.split = function(s, p)
    local rt= {}
    string.gsub(s, '[^'..p..']+', function(w) table.insert(rt, w) end )
    return rt
end
-- 文件保存的根路径
-- local saveRootPath = ngx.var.store_dir .. os.date("/%Y%m/%d/", os.time()+3600*8)
local baseurl = 'http://img.t.isjue.cn/upload'
local urlPath=os.date("/%Y%m/%d/", os.time()+3600*8)
local saveRootPath = "/data/openresty/html/upload" .. urlPath

-- 判断文件夹是否存在，不存在则自动创建
local file=io.open(saveRootPath, "rb")
if file then
        file:close()
else
        local ok,err = os.execute("mkdir -p " .. saveRootPath)
        if not ok then
		response["describeMsg"] = "创建上传目录失败，请检查权限.路径:" .. saveRootPath
		ngx.say(json.encode(response))
		return 
        end
end

ngx.req.read_body()
local body_data=json.decode(ngx.req.get_body_data())
local image_data=body_data["image"]
if not image_data then
        response["describeMsg"] = "未检测到文件"
        ngx.say(json.encode(response))
        return
end
local file_type,ext = string.match(image_data,"^data:(%w+)/(%g-);base64")
if not ext then
	response["describeMsg"] = "文件类型错误"
	ngx.say(json.encode(response))
	return
elseif string.lower(ext) == 'x-zip-compressed' then
	ext = 'zip'

elseif string.lower(ext) ~= 'jpg' and string.lower(ext) ~= 'jpeg' and string.lower(ext) ~= 'png' and string.lower(ext) ~= 'bmp' and string.lower(ext) ~= 'zip' then
	response["describeMsg"] = "不允许上传该文件类型"
	ngx.say(json.encode(response))
	return
end
local fdata = string.split(image_data, ',')
if not fdata then
	response["describeMsg"] = "文件无法识别"
        ngx.say(json.encode(response))
        return
end
local nfile=ngx.md5(image_data) .. '.' .. ext
local file=saveRootPath .. nfile 
fileToSave = io.open(file, "w+")
if not fileToSave then
	response["describeMsg"]="上传失败"
	ngx.say(json.encode(response))
        return
end
local ok,err = fileToSave:write(ngx.decode_base64(fdata[2]))
if not ok then
	response["describeMsg"]="写入文件失败"
        ngx.say(json.encode(response))
        return
end
fileToSave:close()
fileToSave = nil

response["data"]["url"]= baseurl .. urlPath .. nfile
response["returnCode"]=0
response["describeMsg"] = "上传成功"
ngx.say(json.encode(response))
