-- package.path = package.path .. ';../libs/share/lua/5.1/?/init.lua;../libs/share/lua/5.1/?.lua;'

box.cfg {
	background = false;
	logger_nonblock = true;
	read_only = true;
	wal_mode = 'none';
}

local ffi = require 'ffi'
local fiber = require 'fiber'

local function dump(x)
	local j = require'json'.new()
	j.cfg{
		encode_use_tostring = true;
	}
	return j.encode(x)
end


-- print(ffi.C.TNT_UPDATE_INSERT)

local scr = require 'connection.scribe'
local cn = scr("localhost",1463,{})

fiber.create(function()
	-- print("preparing to connect", cn)
	local ch = fiber.channel(1)

	cn.on_connected = function(self,...)
		-- print("connected", ...)
		-- print(cn)
		ch:put(false)
	end
	cn.on_connfail = function(self,...)
		print("connfail", ...)
	end
	cn.on_disconnect = function(self,...)
		print("disconnected", ...)
	end
	cn:connect()
	-- print(cn)
	ch:get()

	-- print("go on,", cn)

	print("log1 = ", cn:log{ cat = "test cat"; msg = "my test message" } )
	print("log2 = ", cn:log{{ cat = "test cat"; msg = "my test message" }} )
	print("log3 = ", cn:log("test cat","my test message") )
	print("log4 = ", cn:log({}) )

end)
