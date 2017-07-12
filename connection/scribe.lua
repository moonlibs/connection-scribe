local obj = require 'obj'
local log = require 'log'
local connection = require 'connection'
local M = obj.class({ debug = {} },'connection.scribe',connection)

local ffi = require 'ffi'
local C = ffi.C
local bin = require 'bin'

local NULL = ffi.cast('void *',0)

local fiber = require 'fiber'

local function dump(x)
	local j = require'json'.new()
	j.cfg{
		encode_use_tostring = true;
	}
	return j.encode(x)
end
local function typedef(t,def)
	if not pcall(ffi.typeof,t) then
		local r,e = pcall(ffi.cdef,def)
		if not r then error(e,2) end
	end
	return ffi.typeof(t)
end
local function fundef(n,def,src)
	src = src or ffi.C
	local f = function(src,n) return src[n] end
	if not pcall(f,src,n) then
		local r,e = pcall(ffi.cdef,def)
		if not r then error(e,2) end
	end
	local r,e = pcall(f,src,n)
	if not r then
		error(e,2)
	end
	return r
end

local VERSION_MASK = ffi.cast('uint32_t',0xffff0000)
local VERSION_1    = ffi.cast('uint32_t',0x80010000);

local M_CALL       = 1
local M_REPLY      = 2
local M_EXCEPTION  = 3
local M_ONEWAY     = 4

local T_STOP       = 0
local T_VOID       = 1
local T_BOOL       = 2
local T_BYTE       = 3
-- local T_I08        = 3
local T_I16        = 6
local T_I32        = 8
local T_U64        = 9
local T_I64        = 10
local T_DOUBLE     = 4
local T_STRING     = 11
-- local T_UTF7       = 11
local T_STRUCT     = 12
local T_MAP        = 13
local T_SET        = 14
local T_LIST       = 15
local T_UTF8       = 16
local T_UTF16      = 1


typedef('sc_hdr_t',[[
#pragma pack (push, 1)
typedef struct {
	unsigned size : 32;
	char     v0   : 8;
	char     v1   : 8;
	char     t0   : 8;
	char     t1   : 8;
	char     len[4];
	char proc[3];

	unsigned seq  : 32;
	struct {
		unsigned char type;
		unsigned char id[2];
	} field;
	struct {
		unsigned char type;
		unsigned int  size : 32;
	} list;
} sc_hdr_t;
#pragma pack (pop)
]])

local def_hdr = ffi.new('sc_hdr_t',{
	size = 0;

	v0 = 0x80; v1 = 1;
	t0 = 0;	t1 = 1;

	len   = {0,0,0,3};
	proc  = "Log";

	field = { type = T_LIST,id={0,1} };
	list  = { T_STRUCT,0};
})
local HDR_SZ = ffi.sizeof('sc_hdr_t')

local seq = 1233
function M.seq()
	seq = seq < 0xffffffff and seq + 1 or 1
	return seq
end

function M:_init(...)
	-- getmetatable( self.__index ).__index.init( self,... )
	self:super(M, '_init')(...)
	self.req = setmetatable({},{__mode = "kv"})
end

function M:_cleanup(e)
	-- getmetatable( self.__index ).__index._cleanup( self,e )
	self:super(M, '_cleanup')(e)
	for k,v in pairs(self.req) do
		if type(v) ~= 'number' then
			v:put(false)
		end
		self.req[k] = nil
	end
end

local
	decode_element,
	decode_struct,
	decode_list,
	decode_map,
	decode_set
;

decode_element = function( t, rbuf )
	if t == T_STOP then
		return
	elseif t == T_STRUCT then
		return decode_struct(rbuf)
	elseif t == T_LIST then
		return decode_list(rbuf)
	elseif t == T_MAP then
		return decode_map(rbuf)
	elseif t == T_SET then
		return decode_set(rbuf)
	elseif t == T_BYTE then
		return rbuf:u8()
	elseif t == T_I16 then
		return rbuf:i16be()
	elseif t == T_I32 then
		return rbuf:i32be()
	elseif t == T_I64 then
		return rbuf:i64be()
	elseif t == T_U64 then
		return rbuf:u64be()
	elseif t == T_DOUBLE then
		return rbuf:doublebe()
	elseif t == T_STRING then
		local len = rbuf:u32be()
		return rbuf:str(len)
	elseif t == T_UTF8 then
		local len = rbuf:u32be()
		return rbuf:str(len)
	elseif t == T_BOOL then
		return rbuf:u8() ~= 0

	elseif t == T_UTF16 then -- is it ok
		local len = rbuf:u32be()
		return rbuf:str(len)
	elseif t == T_VOID then
		return NULL
	else
		error("unsupported type "..t)
	end
end
decode_list = function( rbuf )
	local subtype = rbuf:u8()
	local count = rbuf:u32be()
	local ret = {}
	for i = 1,count do
		table.insert(ret,decode_element(subtype, rbuf))
	end
	return ret
end
decode_map = function( rbuf )
	local keytype = rbuf:u8()
	local valtype = rbuf:u8()
	local count = rbuf:u32be()
	local ret = {}
	for i = 1,count do
		local key = decode_element(keytype, rbuf)
		local val = decode_element(valtype, rbuf)
		ret[key] = val
	end
	return ret
end
decode_set = function( rbuf )
	local valtype = rbuf:u8()
	local count = rbuf:u32be()
	local ret = {}
	for i = 1,count do
		local key = decode_element(keytype, rbuf)
		ret[key] = key
	end
	return ret
end
decode_struct = function( rbuf )
	local ret = {}
	while true do
		local field_type = rbuf:u8()
		if field_type == T_STOP then
			return ret
		else
			local field_id = rbuf:u16be()
			ret[ field_id ] = decode_element( field_type, rbuf )
		end
	end
end

local function decode_message(rbuf)
	local len = rbuf:u32be()
	if len < rbuf:avail() then return end
	local next_rec = rbuf.p.c + len

	local version = rbuf:u32be()
	local seq
	local message_type

	if bit.band( version, VERSION_MASK ) > 0 then
		if bit.band( version, VERSION_MASK ) ~= VERSION_1 then
			log.error("Bad version received: %u",version);
			rbuf.p.c = next_rec
			return
		end
		message_type = bit.band(version,0xff)
		local proc_len = rbuf:u32be()
		rbuf:skip(proc_len)
		seq = rbuf:u32be()
	else -- old packet format
		-- version is actually string length
		local proc_len = version
		rbuf:skip(proc_len) -- skip proc
		message_type = rbuf:u8()
		seq = rbuf:u32be()
	end

	if message_type > 0 and message_type < 5 then
		local r,body = pcall(decode_struct,rbuf)
		if not r then
			rbuf.p.c = next_rec
			log.error("Failde to decode: %s",body)
			return
		end
		if next_rec - rbuf.p.c > 0 then
			log.error("Have leftover %d bytes",tonumber(next_rec - rbuf.p.c))
		end
		rbuf.p.c = next_rec
		return message_type, seq, body
	else
		log.error("Message type is wrong: %s",tostring(message_type))
		rbuf.p.c = next_rec
		return
	end
end

function M:on_read(is_last)
	local rbuf = bin.rbuf( self.rbuf, self.avail )
	print("read\n"..rbuf:dump())
	while rbuf:avail() > 4 do
		local r,message_type,seq,body = pcall(decode_message,rbuf)
		if not r then
			log.error("decode failed: %s",message_type)
		end
		if seq then
			print(message_type, seq, dump(body))
			if self.req[ seq ] then
				self.req[ seq ]:put({message_type, body})
			else
				log.error("Unknown response #%s: %s",seq, dump(body))
			end
		else
			-- skip, error was logged
		end
		-- self:on_connect_reset(errno.ECONNABORTED) -- call for reset connection
	end
	self.avail = rbuf:avail()
	return
end


function M:_waitres( seq )
	local ch = fiber.channel(1)
	self.req[ seq ] = ch
	local now = fiber.time()
	local body = ch:get( self.timeout ) -- timeout?
	if body then
		--[[
			M_REPLY     = { [0] = reply_code }
			M_EXCEPTION = { [1] = error_message, [2] = error_code }
		]]
		if body[1] == M_REPLY then
			if body[2][0] then
				return tonumber(body[2][0])
			else
				return body[2]
			end
		elseif body[1] == M_EXCEPTION then
			local errmsg = ''
			if body[2][2] then
				errmsg = errmsg .. '['..tostring(body[2][2])..'] '
			end
			if body[2][1] then
				errmsg = errmsg .. tostring(body[2][1])
			end
			print("do error", errmsg, dump(body))
			error( errmsg, 2 )
		else
			error("Bad reply "..tostring(body[1])..": "..dump(body[2]),2)
		end
	elseif body == false then
		self.req[ seq ] = nil
		self.ERROR = nil
		error( string.format( "Request #%s error: %s after %0.4fs", seq, self.lasterror, fiber.time() - now ), 2 )
	else
		self.req[ seq ] = now
		self.ERROR = nil
		error( string.format( "Request #%s timed out after %0.4fs", seq, fiber.time() - now ), 2)
	end

	-- body
end

--[[
scribe:log(cat,message)
scribe:log{ cat = "category", msg = "message"}
scribe:log{ { cat = "cat1", msg = "msg1"}, { cat = "cat2", msg = "msg2"}, ... }

]]

function M:log(...)
	local messages
	if type(...) == 'table' then
		local t = ...
		if #t == 0 then
			messages = {t}
		else
			messages = t
		end
	else
		local cat,msg = ...
		messages = {{cat=cat,msg=msg}}
	end

	local sz = HDR_SZ
	-- print(sz)
	for _,rec in pairs(messages) do
		if rec.cat then
			sz = sz+1+2+4+#rec.cat
		end
		if rec.msg then
			sz = sz+1+2+4+#rec.msg
		end
		sz = sz+1
	end

	sz = sz+1
	-- print("pkt size = ",sz)
	
	local buf = bin.fixbuf(sz)
	local hdr = ffi.cast( 'sc_hdr_t *', buf:alloc(HDR_SZ) )
	ffi.copy(hdr,def_hdr,HDR_SZ)

	local seq = self.seq()

	hdr.seq = bin.htobe32( seq )
	hdr.list.size = bin.htobe32( #messages )

	for _,rec in pairs(messages) do
		if rec.cat then
			buf:uint8(T_STRING)
			buf:uint16be(1)
			buf:uint32be(#rec.cat)
			buf:copy(rec.cat)
		end
		if rec.msg then
			buf:uint8(T_STRING)
			buf:uint16be(2)
			buf:uint32be(#rec.msg)
			buf:copy(rec.msg)
		end
		buf:uint8(0)
	end
	buf:uint8(0)

	local p,len = buf:pv()
	-- print(sz, " ", len)
	hdr = ffi.cast( 'sc_hdr_t *', p )
	hdr.size = bin.htobe32( len - 4 )
	-- print(buf:dump())

	-- rrr(buf:reader())

	self:push_write(buf:export());
	self:flush()
	return self:_waitres(seq)
end

return M