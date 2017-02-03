function rmComments(str)
   local nstr, i, op, cl, s = "", 1
   repeat
      s = str:sub(i, i + 1)
      if s == "--" then
	 i = i + 2
	 if str:sub(i, i) == "[" then
	    i = i + 1
	    op = 0
	    while str:sub(i, i) == "=" do
	       op = op + 1
	       i = i + 1
	    end
	    if str:sub(i, i) == "[" then
	       while i < #str do
		  repeat
		     i = i + 1
		  until (i == #str or str:sub(i, i) == "]")
		  i = i + 1
		  cl = 0
		  while str:sub(i, i) == "=" do
		     cl = cl + 1
		     i = i + 1
		  end
		  if cl == op and str:sub(i, i) == "]" then
		     repeat
			i = i + 1
			s = str:sub(i, i)
		     until (i > #str or s ~= " " and s ~= "\n" and s ~= "\t")
		     break
		  end
	       end
	    else
	       repeat
		  i = i + 1
	       until (i > #str or str:sub(i, i) == "\n")
	    end
	 else
	    repeat
	       i = i + 1
	    until (i > #str or str:sub(i, i) == "\n")
	    i = i + 1
	 end
      else
	 nstr = nstr .. str:sub(i, i)
	 i = i + 1
      end
   until (i > #str)
   return nstr
end

function isOperator(str)
   ops = { "^", "-", "*", "/", "[[", "]]", "+", "..", ">", "<", ">=", "<=", "~=", "==",
	   "=", ".", ":", "[", "]", "{", "}", ",", ";", "\"", "(", ")", "..." }
   for i, v in ipairs(ops) do
      if str == v then
	 return v
      end
   end
   return false
end

function isReserved(str)
   ops = { "local", "or", "and", "not", "for", "in", "do", "while", "repeat",
	   "until", "if", "then", "end", "function" }
   for i, v in ipairs(ops) do
      if str == v then
	 return v
      end
   end
   return false
end

function split(str)
   local t, s, n, i, j, ls = "", "", "", 1, 1, {}
   while (i <= #str) do
      s = str:sub(i, i + 2)
      t = isOperator(s) or isOperator(s:sub(1, 2)) or isOperator(s:sub(1, 1))
      if t then
	 if n ~= "" then
	    ls[j] = n
	    n = ""
	    j = j + 1
	 end
	 if t == "\"" or t == "\'" then
	    s = t
	    repeat
	       n = n .. s
	       i = i + 1
	       s = str:sub(i, i)
	    until (s == t or i >= #str)
	    ls[j] = n .. s
	    n = ""
	    i = i + 1
	    j = j + 1
	 elseif t == "[" then
	    repeat
	       n = n .. s
	       i = i + 1
	       s = str:sub(i, i)
	    until (s == "]" or i >= #str)
	    ls[j] = n .. s
	    n = ""
	    i = i + 1
	    j = j + 1
	 elseif t == "[[" then
	    repeat
	       n = n .. s
	       i = i + 1
	       s = str:sub(i, i)
	    until (s == "]]" or i >= #str)
	    ls[j] = n .. s
	    n = ""
	    i = i + 1
	    j = j + 1
	 elseif t == "(" then
	    s = 1
	    repeat
	       n = n .. t
	       i = i + 1
	       t = str:sub(i, i)
	       if t == "(" then
		  s = s + 1
	       elseif t == ")" then
		  s = s - 1
	       end
	    until (s == 0 or i >= #str)
	    ls[j] = n .. t
	    n = ""
	    i = i + 1
	    j = j + 1
	 else
	    ls[j] = t
	    j = j + 1
	    i = i + #t
	    s = str:sub(i, i)
	    while s == " " or s == "\t" do
	       i = i + 1
	       s = str:sub(i, i)
	    end
	    if str:sub(i, i) == "\n" then
	       i = i + 1
	    end
	 end
      else
	 t = s:sub(1, 1)
	 if t == " " or t == "\n" or t == "\t" then
	    if n ~= "" then
	       ls[j] = n
	       n = ""
	       j = j + 1
	    end
	 else
	    n = n .. t
	 end
	 i = i + 1
      end
   end
   if n ~= "" then
      ls[j] = n
   end
   return ls
end

function clean(tab)
   local ntab, len = {}, 0
   for i, v in pairs(tab) do
      len = len + 1
      ntab[len] = v
   end
   return ntab
end

function flatten(astr)
   local s = ""
   for i, v in ipairs(astr) do
      if i == 1 then
	 s = s .. v
      else
	 s = s .. " " .. v
      end
   end
   if s:sub(1, 1) == "(" then
      return s:sub(2, #s - 1)
   end
   return s
end

function filter(str)
   local astr = split(str)
   local mem
   for i, v in ipairs(astr) do
      if v:sub(1, 1) == "(" then
	 astr[i] = "(" .. flatten(filter(v:sub(2, #v - 1))) .. ")"
      end
   end
   -- Priority level 1 - Power: ^ [right-associative]
   for i = #astr - 1, 2, -1 do
      if astr[i] == "^" then
	 astr[i - 1] = "(" .. astr[i - 1] .. " ^ " .. astr[i + 1] .. ")"
	 astr[i + 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 2 - Unary: - not [left-associative]
   mem = true
   for i = 1, #astr - 1 do
      if mem and (astr[i] == "-" or astr[i] == "not") then
	 astr[i + 1] = "(" .. astr[i] .. " " .. astr[i + 1] .. ")"
	 astr[i] = nil
	 mem = false
      else
	 mem = astr[i]
	 mem = isOperator(mem) or isReserved(mem)
      end
   end
   astr = clean(astr)
   -- Priority level 3 - Multiplicative: * / [left-associative]
   for i = 2, #astr - 1 do
      mem = astr[i]
      if mem == "*" or mem == "/" then
	 astr[i + 1] = "(" .. astr[i - 1] .. " " .. mem .. " " .. astr[i + 1] .. ")"
	 astr[i - 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 4 - Additive: + - [left-associative]
   for i = 2, #astr - 1 do
      mem = astr[i]
      if mem == "+" or mem == "-" then
	 astr[i + 1] = "(" .. astr[i - 1] .. " " .. mem .. " " .. astr[i + 1] .. ")"
	 astr[i - 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 5 - Concatenation: .. [right-associative]
   for i = #astr - 1, 2, -1 do
      if astr[i] == ".." then
	 astr[i - 1] = "(" .. astr[i - 1] .. " .. " .. astr[i + 1] .. ")"
	 astr[i + 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 6 - Boolean: == ~= < > <= >= [left-associative]
   for i = 2, #astr - 1 do
      mem = astr[i]
      if mem == "==" or mem == "~=" or mem == "<" or mem == ">" or mem == "<=" or mem == ">=" then
	 astr[i + 1] = "(" .. astr[i - 1] .. " " .. mem .. " " .. astr[i + 1] .. ")"
	 astr[i - 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 7 - Conjunction: and [left-associative]
   for i = 2, #astr - 1 do
      mem = astr[i]
      if mem == "and" then
	 astr[i + 1] = "(" .. astr[i - 1] .. " and " .. astr[i + 1] .. ")"
	 astr[i - 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   -- Priority level 8 - Disjunction: or [left-associative]
   for i = 2, #astr - 1 do
      mem = astr[i]
      if mem == "or" then
	 astr[i + 1] = "(" .. astr[i - 1] .. " or " .. astr[i + 1] .. ")"
	 astr[i - 1] = nil
	 astr[i] = nil
      end
   end
   astr = clean(astr)
   return astr
end

function parenthesize(str)
   local line, nstr, i, indent, s = "", "", 1, 0
   while (i <= #str) do
      s = str:sub(i, i)
      if s == "\n" then
	 s = filter(line)
	 if s[1] == "do" or s[1] == "if" or s[1] == "for" or s[1] == "while" or s[1] == "function" or
	 s[1] == "repeat" then
	    for i = 1, indent do
	       nstr = nstr .. "\t"
	    end
	    indent = indent + 1
	 elseif s[1] == "end" or s[1] == "until" then
	    indent = indent - 1
	    for i = 1, indent do
	       nstr = nstr .. "\t"
	    end
	 elseif s[1] == "else" or s[1] == "elseif" then
	    for i = 1, indent - 1 do
	       nstr = nstr .. "\t"
	    end
	 else  
	    for i = 1, indent do
	       nstr = nstr .. "\t"
	    end
	 end
	 nstr = nstr .. flatten(s) .. "\n"
	 line = ""
      else
	 line = line .. s
      end
      i = i + 1
   end
   return nstr
end

-- ÉVENTUELLEMENT PIPELINER LE PRÉPROCESSEUR (quand le code va être moins laid)

function rmSelf(str)
   local mem, s, i, nstr = "", "", 0, ""
   while i <= #str do
      i = i + 1
      s = str:sub(i, i)
      nstr = nstr .. s
      if s == " " or s == "\t" or s == "\n" then
	 i = i + 1
	 s = str:sub(i, i)
	 if s == ":" then
	    i = i + 1
	    nstr = nstr .. ". "
	    repeat
	       i = i + 1
	       s = str:sub(i, i)
	       nstr = nstr .. s
	    until (s == "(")
	    nstr = nstr .. mem .. " , "
	    mem = ""
	 else
	    nstr = nstr .. s
	    mem = s
	 end
      else
	 mem = mem .. s
      end
   end
   return nstr
end

function rmDot(str)
   local s, i, nstr = "", 0, ""
   while i <= #str do
      i = i + 1
      s = str:sub(i, i)
      nstr = nstr .. s
      if s == " " or s == "\t" or s == "\n" then
	 i = i + 1
	 s = str:sub(i, i)
	 if s == "." then
	    i = i + 1
	    s = "[\""
	    repeat
	       nstr = nstr .. s
	       i = i + 1
	       s = str:sub(i, i)
	    until (s == " ")
	    nstr = nstr .. "\"] "
	 else
	    nstr = nstr .. s
	 end
      end
   end
   return nstr
end
--[[
if arg[1] == nil then
   arg[1] = "test"
end

file = io.open(arg[1] ..  ".lua", "r")
text = file:read("all")
file:close()
file = io.open(arg[1] .. ".pp.lua", "w+")
file:write(parenthesize(rmComments(text)))
file.close()
]]
file = io.open("unit-tests/test.lua", "r")
text = file:read("all")
file:close()
file = io.open("unit-tests/test.pp.lua", "w+")
file:write(rmDot(rmSelf(parenthesize(rmComments(text)))))
file:close()
