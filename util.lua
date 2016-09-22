require("middleclass")

function iterate( lo, hi, fn )
  local cur = lo
  if lo > hi then
    while cur >= hi do fn(cur) ; cur = cur - 1 end
  else 
    while cur <= hi do fn(cur) ; cur = cur + 1 end
  end
end


function range(from, to, step)
  step = step or 1
  return function(_, lastvalue)
    local nextvalue = lastvalue + step
    if step > 0 and nextvalue <= to or step < 0 and nextvalue >= to or
       step == 0
    then
      return nextvalue
    end
  end, nil, from - step
end

-- Creates an immutable table
function const(table)
   return setmetatable({}, {
     __index = table,
     __newindex = function(table, key, value)
                    error("Attempt to modify read-only table")
                  end,
     __metatable = false
   });
end


-- this is a top level clone
function clone( x )
  if type(x)~="table" then return x end  -- nothing but tables are mutable, right?
  if x.clone then return x:clone() end   -- some tables know how to clone themselves
  local r = {}
  for i,v in ipairs( x ) do table.insert( r,v ) end
  for k,v in pairs( x ) do r[k]=v end
  local mt = getmetatable( x )
  if mt then return setmetatable( r, mt ) end
  return r
end

function deepClone(x)
  if type(x)~="table" then return x end  -- nothing but tables are mutable, right?
  if x.clone then return x:clone() end   -- some tables know how to clone themselves
  local r = {}
  for i,v in ipairs( x ) do table.insert( r, deepClone(v) ) end
  for k,v in pairs( x ) do r[k]=deepClone(v) end
  local mt = getmetatable( x )
  if mt then setmetatable( r, mt ) end
  return r
end


function updateMap(m,m2) for k,v in pairs(m2) do m[k] = v end end

-- couple of functions to extract keys or values from hash like tables
function keys(x) local r = List(); for k,v in pairs(x) do if k~='class' then r:append( k ) end end ; return r; end
function values(x) local r = List(); for k,v in pairs(x) do r:append( v ) end ; return r; end


-- these methods generally return a new list or map
List=class("List")

function List:initialize(t)
  if t and type(t)=='table' then 
    for i,v in ipairs(t) do table.insert(self, v ) end
  end
  
end

function List:len() return #self end
function List:empty() return #self==0 end
function List:first() if #self then return self[1] else return nil end end
function List:last() if #self then return self[#self] else return nil end end
function List:append(...) for i,v in ipairs(arg) do table.insert(self,v) end return self end

function List:any(fn)
  for i,v in ipairs(self) do if fn(v) then return true end end
  return false
end

function List:count(fn)
  local n = 0
  for i,v in ipairs(self) do if fn(v) then n = n + 1 end end
  return n
end

function List:smallest(fn) return self:sortBy(fn):first() end
function List:largest(fn)  return self:sortBy(fn):last() end

-- a comprehension like method
function List:collectIf( pred, fn )
  return self:filter( pred ):collect( fn ) 
  -- or return self:groupBy( pred )[true]:collect( fn )
end


-- iterate over a list
function List:each(f)
  for i, v in ipairs(self) do 
    f( v, i )
  end
  return self
end

-- commonly called map in functional languages
function List:collect(fn)
  local r = List()
  for i,v in ipairs(self) do
    r:append( fn(v,i) )
  end
  return r
end

-- convert a list into a map using a function, returns a table keys mapped to lists of items
function List:groupBy(fn)
  local r = List()
  local key = nil
  for i,v in ipairs( self ) do
    key = fn( v )
    if r[key] then r[key]:append( v ) else r[key] = List{ v } end
  end
  return r;
end

-- sort using a function , or a field name/index
function List:sortBy(f)
  local m 
  if type(f)~="function" then 
    m = self:groupBy( function(x) return x[f] end )
  else 
    m = self:groupBy( f )
  end
  local keylist = keys(m)
  table.sort( keylist )
  local r = List()
  for i, key in ipairs(keylist) do 
    for i,v2 in ipairs( m[key] ) do
      table.insert( r, v2 )
    end
  end
  return r
end

-- remove items from a list based on a function
function List:filter( fn )
  local r = List()
  for i,v in ipairs( self ) do
    if fn(v) then table.insert( r, v ) end
  end
  return r;
end

-- remove duplicates from a list based on a passed function
function List:unique( fn )
  local r = List()
  local seen = {}
  for i,v in ipairs( self ) do
    k = fn( v )
    if not seen[k] then 
      r:append( v ) 
      seen[k] = true 
    end
  end
  return r;
end

-- self explanatory
function List:reverse()
  local r = List()
  local n = #self
  while n > 0 do table.insert( r, self[n] ) ; n = n - 1 end
  return r;
end

-- concat two lists
function List:__add( other )
  local newlist= List(self)
  for i,v in ipairs( other ) do table.insert( newlist, v ) end
  return newlist
end

-- this actually modifies the list, returns itself; advantage when named members in list1
function List:addAll( ... )
  for i,v in ipairs(arg) do table.insert( self, v ) end
  return self
end

function List:findWhere(fn)
  for i,v in ipairs( self ) do if fn(v) then return v end end
end

function List:findAllWhere(fn)
  local r = List()
  for i,v in ipairs( self ) do if fn(v) then table.insert(r,v) end end
  return r
end

function List:indexOf( f )
  for i,v in ipairs( self ) do if f==v then return i end end
  return 0
end

function List:contains( f) return self:indexOf(f)>0 end
function List:removeAt( i ) return table.remove( self, i ) end
function List:remove( v ) local index = self:indexOf(v); if index>0 then self:removeAt( index ) end end

function List:sum() local total=0; for i,v in ipairs(self) do total = total + v end ; return total end

function List:min() 
  if self:empty() then return nil end 
  local lo = self[1]; 
  for i,v in ipairs(self) do 
    if v < lo then lo = v end
  end
  return lo
end
  
function List:max() 
  if self:empty() then return nil end
  local hi = self[1]; 
  for i,v in ipairs(self) do 
    if v > hi then hi = v end
  end
  return hi
end




