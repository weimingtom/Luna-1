--!! TMP
comp_file = "unit-tests/test"
_SPACE = "   "

-- Error managment values
--------------------------------------------------------------------------------
local linum, chnum = 1, 1
local typerr = "Unknown"

-- Boolean functions
--------------------------------------------------------------------------------
function isWhitespace(str)
   if str == " "  or
      --str == "\n" or !!Conserver les choix de l'utilisateur dans le placement de "\n"
      str == "\r" or
      str == "\t"
   then
      return true
   end
   return false
end

function isOperator(str)
   if -- Single char operators
      str == "-" or
      str == "+" or
      str == "/" or
      str == "*" or
      str == "~" or
      str == "^" or
      str == "." or
      str == ":" or
      str == "<" or
      str == ">" or
      str == "#" or
      -- 2 char operators
      str == "~=" or
      str == ">=" or
      str == "<=" or
      str == "==" or
      str == ".." or
      str == "--" or
      str == "or" or
      -- 3 char operators
      str == "and"  or
      str == "not"
   then
      return true
   end
   return false
end

function isPunctuation(str)
   return str == "=" or str == ","
end

function isDelimiter(str)
   if -- Single char delimiters
      str == "{"  or
      str == "}"  or
      str == "("  or
      str == ")"  or
      str == "\"" or
      str == "'"  or
      str == "["  or
      str == "]"  or
      -- 2 char delimiters
      str == "[[" or
      str == "[=" or
      str == "=]" or
      str == "]]"
   then
      return true
   end
   return false
end

function isEnv(str)
   if str == "function"  or
      str == "if" or
      str == "then"  or
      str == "else"  or
      str == "elseif" or
      str == "end"  or
      str == "for"  or
      str == "while" or
      str == "do"  or
      str == "in" or
      str == "repeat"  or
      str == "until"  
   then
      return true
   end
   return false
end

function isReserved(str)
   if str == "local"  or
      str == "break"  or
      str == "return"
   then
      return true
   end
   return false
end

-- Parsing functions
--------------------------------------------------------------------------------
function nexttoken(str, i)
   local ret, s = ""

   if i > #str then
      return false, i
   end
   s = str:sub(i, i)
   
   -- Removes whitespaces ahead of expression
   while isWhitespace(s) do
      i = i + 1
      chnum = chnum + 1
      if i > #str then
	 return false, i
      end
      s = str:sub(i, i)
   end

   -- Special cases (3)
   s = str:sub(i, i + 2)
   
   if s == "..." or isOperator(s) then
      chnum = chnum + 2
      return s, i + 3
   end

   -- Special cases (2)
   s = s:sub(1, 2)

   -- String parsing [[]]
   if s == "[=" or s == "[[" then
      return strpar(str, i)
      
   elseif isOperator(s) then
      chnum = chnum + 1
      return s, i + 2
   end

   -- Special cases (1)
   s = s:sub(1, 1)

   if s == "\n" then
      linum = linum + 1
      chnum = 1
      return s, i + 1

      -- String parsing "" and ''
   elseif s == "\"" or s == "'" then
      local t = s
      local ti, tl = i, 0
      ret = ret .. "\""
      
      while true do
	 i = i + 1
	 if i > #str then
	    typerr = "String decleration reached end of file. Expected closing " .. t .. "."
	    helperror()
	    break
	 end
	 s = str:sub(i, i)
	 if t == "'" and s == "\"" then
	    ret = ret .. "\\\""
	 elseif t == "\n" then
	    ret = ret .. "\n"
	    tl = tl + 1
	    ti = i
	 elseif s == t then
	    ret = ret .. "\""
	    break
	    break
	 else
	    ret = ret .. s
	 end
      end
      
      linum = linum + tl
      chnum = i - ti
      return ret, i + 1
      ---------------------------
      
   elseif isOperator(s) or isDelimiter(s) then
      return s, i + 1
   end

   -- Regular case
   while not isWhitespace(s) and not isOperator(s) and not isDelimiter(s) and s ~= "\n" do
      ret = ret .. s
      i = i + 1
      chnum = chnum + 1
      if i > #str then
	 return ret, i
      end
      s = str:sub(i, i)
   end

   return ret, i
end

function scan(arr, dir, op)
end

function readline(str, i, indent)
   local tl, tc, j = linum, chnum
   local ret, token = ""
   token, j = nexttoken(str, i)
   while token do
      if isEnv(token) or token == "\n" then
	 if ret == "" then
	    return token, j
	 else
	    linum = tl
	    chnum = tc
	    return ret, i
	 end
      else
	 ret = ret .. token
	 i = j
	 tl = linum
	 tc = chnum
      end
      token, j = nexttoken(str, i)
   end
   return false, i
end

-- Comment parsing
function compar(str, i)
   local s = str:sub(i, i + 1)
   local line = chnum == 2
   if s == "[=" or s == "[[" then
      s, i = nexttoken(str, i)
      s, i = nexttoken(str, i)
   else
      while s and s ~= "\n" do
	 s, i = nexttoken(str, i)
      end
   end
   if line then
      s, i = nexttoken(str, i)
   end
   return s, i
end

-- String parsing
-- *** Maybe integrate other [very similar] string parsing ("", '')
function strpar(str, i)
      local n, ret = 1, "\""
      local ti, tl = i, 0
      chnum = chnum + 1
      
      repeat
	 n = n + 1
	 i = i + 1
	 s = str:sub(i, i)
      until s == "["
      
      while true do
	 i = i + 1
	 if i > #str then
	    typerr = "Reached end of file, expected closing brackets"
	    helperror()
	    break
	 end
	 s = str:sub(i, i)
	 if s == "\n" then
	    tl = tl + 1
	    ti = i
	    ret = ret .. "\\n\n"
	 elseif s == "\t" then
	    ret = ret .. "\\t"
	 elseif s == "\"" then
	    ret = ret .. "\\\""
	 elseif s == "]" then
	    local m, tmp = 1, s
	    repeat
	       m = m + 1
	       i = i + 1
	       s = str:sub(i, i)
	       tmp = tmp .. s
	    until s == "]" or m > n
	    if m == n then
	       i = i + 1
	       ret = ret .. "\""
	       break
	    else
	       ret = ret .. tmp
	    end
	 else
	    ret = ret .. s
	 end
      end
      
      linum = linum + tl
      chnum = i - ti
      return ret, i
end

-- Preprocessing
--------------------------------------------------------------------------------
function strgen(str, n)
   local ret = ""
   for i = 1, n do
      ret = ret .. str
   end
   return ret
end

----------------------------------------
-- Environment functions
----------------------------------------
function ifenv(str, i, line, indent, elif)
   local ret, tmp = line
   tmp, i, line = _preprocess(str, i, indent + 1, { "then" })
   ret = ret .. tmp .. line .. " "
   tmp, i, line = _preprocess(str, i, indent + 1, { "else", "end" })
   ret = ret .. tmp .. line .. " "
   if line:sub(#line - 3, #line) == "else" then
      tmp, i, line = _preprocess(str, i, indent + 1, { "end" })
      ret = ret .. tmp .. line .. " "
   end
   if elif then
      return ret, i - 4
   else
      return ret, i
   end
end

function doenv(str, i, line, indent, elif)
   local ret, tmp = line
   tmp, i, line = _preprocess(str, i, indent + 1, { "end" })
   ret = ret .. tmp .. line .. " "
   return ret, i
end

function forenv(str, i, line, indent, elif)
   local ret, tmp = line
   tmp, i, line = _preprocess(str, i, indent + 1, { "in", "do" })
   ret = ret .. tmp .. line .. " "
   if line:sub(#line - 1, #line) == "in" then
      tmp, i, line = _preprocess(str, i, indent + 1, { "do" })
      ret = ret .. tmp .. line .. " "
   end
   tmp, i = doenv(str, i, "", indent, elif)
   return ret .. tmp, i
end

function wenv(str, i, line, indent, elif)
   local ret, tmp = line
   tmp, i, line = _preprocess(str, i, indent + 1, { "do" })
   ret = ret .. tmp .. line .. " "
   tmp, i = doenv(str, i, "", indent, elif)
   return ret .. tmp, i
   end

function preprocess(str)
   return _preprocess(str, 1, 0, {})
end

function _preprocess(str, i, indent, stops)
   local ret = "", 1
   local line, tmp = true
   local tl, tc = linum, chnum
   local nl = 0 -- strgen("  ", indent)
   while line do
      line, i = readline(str, i, indent)
      if not line then break end
      
      for n, stop in ipairs(stops) do
	 if line == stop then
	    return ret, i, strgen(_SPACE, nl - 1) .. line
	 end
      end

      if line == "end" then
	 typerr = "Unexpectedly reached \"end\"; was expecting \"" .. stops[1] .. "\""
	 for j = 2, #stops do
	    typerr = typerr .. ", or \"" .. stops[j] .. "\""
	 end
	 typerr = typerr .. "."
	 helperror()
      end

      ---------- NL ----------
      if line == "\n" then
	 ret = ret .. line
	 nl = indent
      
      ---------- IF  ----------
      elseif line == "if" then
	 line = strgen(_SPACE, nl) .. line .. " "
	 tmp, i = ifenv(str, i, line, indent, false)
	 ret = ret .. tmp
      elseif line == "elseif" then
	 line = strgen(_SPACE, nl - 1) .. "else if "
	 tmp, i = ifenv(str, i, line, indent + 1, true)
	 ret = ret .. tmp

      ---------- DO  ----------
      elseif line == "do" then
	 line = strgen(_SPACE, nl) .. line .. " "
	 tmp, i = doenv(str, i, line, indent, false)
	 ret = ret .. tmp

      ---------- FOR ----------
      elseif line == "for" then
	 line = strgen(_SPACE, nl) .. line .. " "
	 tmp, i = forenv(str, i, line, indent, false)
	 ret = ret .. tmp

      ---------- WHL ----------
      elseif line == "while" then
	 line = strgen(_SPACE, nl) .. line .. " "
	 tmp, i = wenv(str, i, line, indent, false)
	 ret = ret .. tmp

      ---------- RPT ----------
      elseif line == "repeat" then

      ---------- FCT ----------
      elseif line == "function" then

      ---------- GEN ----------
      else
	 ret = ret .. strgen(_SPACE, nl) .. line .. " "
	 nl = 0
      end
      
   end
   if indent > 0 then
      typerr = "Error in scope, expected to reach \"" .. stops[1] .. "\""
      for j = 2, #stops do
	 typerr = typerr .. ", or \"" .. stops[j] .. "\""
      end
      typerr = typerr .. ".\nReached end of file instead."
      linum, chnum = tl, tc
      helperror()
   end
   return ret
end

-- Error handling
--------------------------------------------------------------------------------
function helperror()
   local file, text = io.open("test.lua", "r")
   for i = 1, linum do
      text = file:read("line")
   end
   file:close()
   print("FILE: test.lua")
   print("Error at line " .. tostring(linum) .. ": " .. typerr)
   print(text)
   for i = 1, chnum do
      io.write(" ")
   end
   print("^")
   os.exit()
end

-- Program
--------------------------------------------------------------------------------
local file = io.open("test.lua", "r")
local text = file:read("all")
file:close()
file = io.open("test.pp.lua", "w+")
file:write(preprocess(text))
file:close()