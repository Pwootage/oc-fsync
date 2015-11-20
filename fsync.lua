-- MIT licensed. For more details: https://github.com/Pwootage/oc-fsync --
local component = require("component")
local internet = require("internet")
local bit32 = require("bit32")
local filesystem = require("filesystem")
local term = require("term")
local event = require("event")

-- Parse args
local args = { ... }
local server = table.remove(args, 1)
local port = 3000
if server and server:find(":") then
  local tmp = server
  local ind = tmp:find(":")
  server = tmp:sub(1, ind - 1)
  port = tonumber(tmp:sub(ind + 1))
end
local root = "/"
local hardwareHash = false

while (#args > 0) do
  local next = table.remove(args, 1)
  if next == "--hardwareHash" then
    hardwareHash = true
  elseif next == "--root" then
    root = table.remove(args, 1)
    if not root then
      print("Must provide an argument to --root")
    end
    if not (root:sub(-1) == "/") then root = root .. "/" end
  end
end

fileHashes = {}

local function main()
  print("OpenComputers File Sync")
  print("Federated OpenComputers <-> Real Computer File Sync")
  print("")

  if not component.isAvailable("internet") then
    termColor(0xFF0000)
    print("ERROR:")
    print("This program requires an internet card to function.")
    print("Please add one, and try again.")
    termColor(0xFFFFFF)
    return
  end

  if not server then
    print("Usage: fsync <server>[:port] [base directory] [-options]")
    print("Available options:")
    print("--root <directory>\tChoose directory to serve")
    print("--hardwareHash\tUse data card's hash function (requires data card)")
    return
  end

  print("Will connect to server " .. server .. " port " .. port)
  print("Serving from file root " .. root)
  if hardwareHash then
    if component.isAvailable("data") then
      print("--hardwareHash set and data card available; will use hardware MD5.")
    else
      termColor(0x00FFFF)
      print("Data card not available; remove --hardwareHash parameter or add data card")
      termColor(0xFFFFFF)
      return
    end
  end
  print("Calculating hash of all files in direcotry...")
  local hashCount = 0
  fsTraverse(root, function(file)
    local f = io.open(file, "rb")
    local hash = hashBytes(f:read("*all"))
    f:close()
    fileHashes[file] = hash
    hashCount = hashCount + 1
    if (hashCount % 10 == 0) then
      term.write(".", true)
    end
    handleEvents()
  end)
  print()
  print("Calculated " .. hashCount .. " hashes.")
  print("Connecting to " .. server .. " port " .. port)

  local socket = internet.open(server, port)
  socket:setTimeout(1)

  while socket do
    local messageType = socket:read("*line")
    if messageType then
      print(messageType)
    end
    handleEvents()
  end

  if not socket then
    termColor(0xFF0000)
    print("Connection lost. Exiting.")
    termColor(0xFFFFFF)
    return
  end
end

function socketRead(socket, size)
end

function handleEvents()
  event.pull(0, "invalid_event_name_just_to_make_signals_process")
end

function termColor(newColor)
  if (component.isAvailable("gpu")) then
    component.gpu.setForeground(newColor)
  end
end

function hashBytes(bytes)
  if hardwareHash then
    return binToHex(component.data.md5(bytes))
  else
    return binToHex(softwareMD5(bytes))
  end
end

function binToHex(hash)
  local ret = ""
  for i = 1, hash:len() do
    ret = ret .. string.format("%02x", string.byte(hash, i))
  end
  return ret
end

function fsTraverse(path, fn)
  files = filesystem.list
  if files then
    for file in filesystem.list(path) do
      if file:sub(-1) == "/" then
        fsTraverse(path .. file, fn)
      else
        fn(path .. file)
      end
    end
  end
end

softwareMD5 = nil
-- Software MD5 implementation (slightly modified) from https://github.com/kikito/md5.lua/blob/master/md5.lua
-- Also MIT licenced.
do
  -- An MD5 mplementation in Lua, requires bitlib
  -- 10/02/2001 jcw@equi4.com

  -- convert little-endian 32-bit int to a 4-char string
  local function lei2str(i)
    local f = function(s) return string.char(bit32.band(bit32.rshift(i, s), 255)) end
    return f(0) .. f(8) .. f(16) .. f(24)
  end

  -- convert raw string to big-endian int
  local function str2bei(s)
    local v = 0
    for i = 1, #s do
      v = v * 256 + string.byte(s, i)
    end
    return v
  end

  -- convert raw string to little-endian int
  local function str2lei(s)
    local v = 0
    for i = #s, 1, -1 do
      v = v * 256 + string.byte(s, i)
    end
    return v
  end

  -- cut up a string in little-endian ints of given size
  local function cut_le_str(s, ...)
    local o, r = 1, {}
    local args = { ... }
    for i = 1, #args do
      table.insert(r, str2lei(string.sub(s, o, o + args[i] - 1)))
      o = o + args[i]
    end
    return r
  end

  local swap = function(w) return str2bei(lei2str(w)) end

  local function hex2binaryaux(hexval)
    return string.char(tonumber(hexval, 16))
  end

  local function hex2binary(hex)
    local result, _ = hex:gsub('..', hex2binaryaux)
    return result
  end

  local CONSTS = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
    0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
  }

  local f = function(x, y, z) return bit32.bor(bit32.band(x, y), bit32.band(-x - 1, z)) end
  local g = function(x, y, z) return bit32.bor(bit32.band(x, z), bit32.band(y, -z - 1)) end
  local h = function(x, y, z) return bit32.bxor(x, bit32.bxor(y, z)) end
  local i = function(x, y, z) return bit32.bxor(y, bit32.bor(x, -z - 1)) end
  local z = function(f, a, b, c, d, x, s, ac)
    a = bit32.band(a + f(b, c, d) + x + ac, 0xFFFFFFFF)
    -- be *very* careful that left shift does not cause rounding!
    return bit32.bor(bit32.lshift(bit32.band(a, bit32.rshift(0xFFFFFFFF, s)), s), bit32.rshift(a, 32 - s)) + b
  end

  local function transform(A, B, C, D, X)
    local a, b, c, d = A, B, C, D
    local t = CONSTS

    a = z(f, a, b, c, d, X[0], 7, t[1])
    d = z(f, d, a, b, c, X[1], 12, t[2])
    c = z(f, c, d, a, b, X[2], 17, t[3])
    b = z(f, b, c, d, a, X[3], 22, t[4])
    a = z(f, a, b, c, d, X[4], 7, t[5])
    d = z(f, d, a, b, c, X[5], 12, t[6])
    c = z(f, c, d, a, b, X[6], 17, t[7])
    b = z(f, b, c, d, a, X[7], 22, t[8])
    a = z(f, a, b, c, d, X[8], 7, t[9])
    d = z(f, d, a, b, c, X[9], 12, t[10])
    c = z(f, c, d, a, b, X[10], 17, t[11])
    b = z(f, b, c, d, a, X[11], 22, t[12])
    a = z(f, a, b, c, d, X[12], 7, t[13])
    d = z(f, d, a, b, c, X[13], 12, t[14])
    c = z(f, c, d, a, b, X[14], 17, t[15])
    b = z(f, b, c, d, a, X[15], 22, t[16])

    a = z(g, a, b, c, d, X[1], 5, t[17])
    d = z(g, d, a, b, c, X[6], 9, t[18])
    c = z(g, c, d, a, b, X[11], 14, t[19])
    b = z(g, b, c, d, a, X[0], 20, t[20])
    a = z(g, a, b, c, d, X[5], 5, t[21])
    d = z(g, d, a, b, c, X[10], 9, t[22])
    c = z(g, c, d, a, b, X[15], 14, t[23])
    b = z(g, b, c, d, a, X[4], 20, t[24])
    a = z(g, a, b, c, d, X[9], 5, t[25])
    d = z(g, d, a, b, c, X[14], 9, t[26])
    c = z(g, c, d, a, b, X[3], 14, t[27])
    b = z(g, b, c, d, a, X[8], 20, t[28])
    a = z(g, a, b, c, d, X[13], 5, t[29])
    d = z(g, d, a, b, c, X[2], 9, t[30])
    c = z(g, c, d, a, b, X[7], 14, t[31])
    b = z(g, b, c, d, a, X[12], 20, t[32])

    a = z(h, a, b, c, d, X[5], 4, t[33])
    d = z(h, d, a, b, c, X[8], 11, t[34])
    c = z(h, c, d, a, b, X[11], 16, t[35])
    b = z(h, b, c, d, a, X[14], 23, t[36])
    a = z(h, a, b, c, d, X[1], 4, t[37])
    d = z(h, d, a, b, c, X[4], 11, t[38])
    c = z(h, c, d, a, b, X[7], 16, t[39])
    b = z(h, b, c, d, a, X[10], 23, t[40])
    a = z(h, a, b, c, d, X[13], 4, t[41])
    d = z(h, d, a, b, c, X[0], 11, t[42])
    c = z(h, c, d, a, b, X[3], 16, t[43])
    b = z(h, b, c, d, a, X[6], 23, t[44])
    a = z(h, a, b, c, d, X[9], 4, t[45])
    d = z(h, d, a, b, c, X[12], 11, t[46])
    c = z(h, c, d, a, b, X[15], 16, t[47])
    b = z(h, b, c, d, a, X[2], 23, t[48])

    a = z(i, a, b, c, d, X[0], 6, t[49])
    d = z(i, d, a, b, c, X[7], 10, t[50])
    c = z(i, c, d, a, b, X[14], 15, t[51])
    b = z(i, b, c, d, a, X[5], 21, t[52])
    a = z(i, a, b, c, d, X[12], 6, t[53])
    d = z(i, d, a, b, c, X[3], 10, t[54])
    c = z(i, c, d, a, b, X[10], 15, t[55])
    b = z(i, b, c, d, a, X[1], 21, t[56])
    a = z(i, a, b, c, d, X[8], 6, t[57])
    d = z(i, d, a, b, c, X[15], 10, t[58])
    c = z(i, c, d, a, b, X[6], 15, t[59])
    b = z(i, b, c, d, a, X[13], 21, t[60])
    a = z(i, a, b, c, d, X[4], 6, t[61])
    d = z(i, d, a, b, c, X[11], 10, t[62])
    c = z(i, c, d, a, b, X[2], 15, t[63])
    b = z(i, b, c, d, a, X[9], 21, t[64])

    return A + a, B + b, C + c, D + d
  end

  ----------------------------------------------------------------

  softwareMD5 = function(s)
    local msgLen = #s
    local padLen = 56 - msgLen % 64

    if msgLen % 64 > 56 then padLen = padLen + 64 end

    if padLen == 0 then padLen = 64 end

    s = s .. string.char(128) .. string.rep(string.char(0), padLen - 1) .. lei2str(8 * msgLen) .. lei2str(0)

    assert(#s % 64 == 0)

    local t = CONSTS
    local a, b, c, d = t[65], t[66], t[67], t[68]

    for i = 1, #s, 64 do
      local X = cut_le_str(string.sub(s, i, i + 63), 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4)
      assert(#X == 16)
      X[0] = table.remove(X, 1) -- zero based!
      a, b, c, d = transform(a, b, c, d, X)
    end

    return hex2binary(string.format("%08x%08x%08x%08x", swap(a), swap(b), swap(c), swap(d)))
  end
end

--Invoke main method
main()