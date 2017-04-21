-- Register information
--------------------------------------------------------------------------------
-- Registers (16)
r = { "%rax", "%rbx", "%rcx", "%rdx", "%rbp", "%rsp", "%rsi", "%rdi",
      "%r8", "%r9", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15" }

-- Reserved: %rax, %rsp

-- Usable registers (8)
u_reg  = 1
u_size = 8
u_name = { "%rbx", "%rbp", "%r10", "%r11", "%r12", "%r13", "%r14", "%r15" }
u_cont = {  0,      0,      0,      0,      0,      0,      0,      0     }

-- Calling registers (14)
c = { "%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9", "%xmm0", "%xmm1",
      "%xmm2", "%xmm3", "%xmm4", "%xmm5", "%xmm6", "%xmm7" }

-- Miscellaneous global variables
--------------------------------------------------------------------------------
intro =
   "\t.text\n" ..
   "\t.global\t_main\n" ..
   "\t.global\tmain\n" ..
   "_main:\n" ..
   "main:\n"

outro =
   "\tmov\t$0, %rax\n" ..
   "\tret\n"

-- Internal structures and functions
--------------------------------------------------------------------------------
buf = false

vstack = {}
vsize  = 0

rstack = {}
rsize = 0
-----------------------------------------
function vpush(value)
   vsize = vsize + 1
   vstack[vsize] = value
end

function vpop()
   local tmp = vstack[vsize]
   vstack[vsize] = nil
   vsize = vsize - 1
   --tmp
   if vsize < 0 then
      print("ERROR")
   end
   return tmp
end

function vtop()
   return vstack[vsize]
end

function vat(index)
   return vstack[index]
end

function vfree(index)
   index = vsize - index
   for i = index + 1, vsize do
      vstack[i] = nil
   end
   vsize = index
end

function realsize()
   if buf then
      return vsize + 1
   end
   return vsize
end


function rpush(value)
   rsize = rsize + 1
   rstack[rsize] = value
end

function rpop()
   local tmp = rstack[rsize]
   rstack[rsize] = nil
   rsize = rsize - 1
   return tmp
end

function rtop()
   return rstack[rsize]
end

function rat(index)
   return rstack[index]
end

function rfree(index)
   index = rsize - index
   for i = index + 1, rsize do
      rstack[i] = nil
   end
   rsize = index
end

-- Register handling functions
--------------------------------------------------------------------------------
function available()
   return u_cont[u_reg] == 0
end

function register()
   u_cont[u_reg] = u_cont[u_reg] + 1
   u_reg = (u_reg + 1) % u_size
   return u_name[(u_reg - 1) % u_size]
end

function current()
   return u_name[u_reg - 1]
end

function future()
   return u_name[u_reg]
end

function release()
   u_reg = (u_reg - 1) % u_size
   u_cont[u_reg] = u_cont[u_reg] - 1
   return u_name[u_reg]
end

function replace()
   local n = u_name[u_reg]
   rpush(n)
   for i = 1, vsize do
      if vstack[i] == n then
	 vstack[i] = n
      end
   end
   return "\tpush\t" .. n .. "\n"
end

-- *** Operating functions ***
--------------------------------------------------------------------------------
function push(value)
   local ret = ""
   if buf then
      if available() then
	 ret = "\tmov\t" .. buf .. ", " .. register() .. "\n"
      else
	 ret = replace()
	 ret = ret .. "\tmov\t" .. buf .. ", " .. register() .. "\n"
      end
      vpush(current())
   end
   if value then
      buf = "$" .. value
   else
      vpush(register())
      buf = value
   end
   return ret
end

function pop()
   local top, ret = vtop(), ""
   if type(top) == "number" then
      if top == rsize then
	 buf = rpop()
	 ret = "\tpop\t" .. buf .. "\n"
	 vpop()
      else
	 buf = rat(top)
	 ret = "\tmov\t" .. tostring(8 * (rsize - top)) .. "(%rsp), " .. buf .. "\n"
	 vpop()
      end
   else
      buf = vpop()
   end
   release()
   return ret
end

function free(index)
   if index == 0 then return "" end
   if buf then
      buf = false
      index = index - 1
      if index == 0 then return "" end
   end
   for i = vsize - index + 1, vsize do
      vstack[i] = nil
      release()
   end
   vsize = vsize - index
   return restore()
end

function restore()
   local max, ret = 0, ""
   if (vsize + 1) % u_size ~= u_reg then
      print("Stack corruption")
   end
   for i = 1, vsize do
      if type(vstack[i]) == "number" then
	 if vstack[i] > max then
	    max = vstack[i]
	 end
      end
   end
   for i = max + 1, rsize do
      rstack[i] = nil
   end
   if rsize - max ~= 0 then
      ret = "\tadd\t$" .. tostring((rsize - max) * 8) .. ", %rsp\n"
   end
   rsize = max
   return ret
end

function get(index)
   if buf then
      if index == 0 then
	 return buf
      else
	 index = index - 1
      end
   end
   local val = vat(vsize - index)
   if type(val) == "string" then
      return val
   else
      return tostring(8 * (rsize - val)) .. "(%rsp)"
   end
end

function add()
   local ret = ""
   if not buf then
      ret = pop()
   end
   ret = ret .. "\tadd\t" .. buf .. ", " .. vtop() .. "\n"
   buf = false
   return ret
end

-- Parsing functions
--------------------------------------------------------------------------------
function readline(str, i)
   if i > #str then
      return false, i
   end
   local s, ret = str:sub(i, i), ""
   while s ~= "\n" and i <= #str do
      ret = ret .. s
      i = i + 1
      s = str:sub(i, i)
   end
   return ret, i + 1
end

function separate(instr)
   local i = 1
   local s, ret = instr:sub(i, i), ""
   while s ~= "\t" and i <= #instr do
      ret = ret .. s
      i = i + 1
      s = instr:sub(i, i)
   end
   return ret, instr:sub(i + 1, #instr)
end

---------- PROGRAM ----------
function translate(text)
   local ret, buf = intro, false
   local s, i = readline(text, 1)
   local instr, value
   while s do
      instr, value = separate(s)
      ---------------------------
      if instr == "int" then
	 value = 8 * tonumber(value)
	 ret = ret .. push(tostring(value))
      elseif instr == "add" then
	 ret = ret .. add()
      elseif instr == "ref" then
	 ret = ret .. push(get(tonumber(value)))
      elseif instr == "var" then
	 -- TBD
      elseif instr == "sets" then
	 base = realsize()
	 target = tonumber(value) + base - 1
      elseif instr == "stack" then
	 for i = realsize(), target do
	    ret = ret .. push(false)
	 end
      elseif instr == "modif" then
	 modif = {}
	 msize = tonumber(value)
	 mbase = realsize()
	 for j = 1, msize do
	    s, i = readline(text, i)
	    instr, value = separate(s)
	    if instr == "ref" then
	       modif[j] = tonumber(value)
	    elseif instr == "var" then
	       -- TBD
	    end
	 end
      elseif instr == "place" then
	 local o1, o2
	 for j = 1, msize do
	    o1 = get(vsize - j - mbase)
	    o2 = get(realsize() - mbase + modif[j])
	    if (o1:sub(1, 1) ~= "%" or o1:sub(1, 1) ~= "$") and o2:sub(1, 1) ~= "%" then
	       o1 = o1 .. ", %rax\n\tmov\t%rax"
	    end
	    ret = ret .. "\tmov\t" .. o1 .. ", " .. o2 .. "\n"
	 end
	 modif = nil
	 ret = ret .. free(realsize() - mbase - msize)
      elseif instr == "free" then
	 ret = ret .. free(tonumber(value))
      end
      ---------------------------
      s, i = readline(text, i)
   end
   return ret .. outro
end

--------------------------------------------------------------------------------

local file = io.open(comp_file .. ".lir", "r")
text = file:read("all")
file:close()
file = io.open(comp_file .. ".s", "w+")
file:write(translate(text))
file:close()

