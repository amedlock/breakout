require("middleclass")


function zero( n ) return math.abs( n ) < 0.001 end
function clamp( n, lo, hi ) return math.max( math.min( n, hi ), lo ) end
function mod( n, m ) if not zero(m) then return n - math.floor(n/m)*m else return 0 end end

function snap( val,step )
  if step then
    local m = mod( val, step )
    if m > step/2 then val = val + ( step - m ) else val = val - m end
  end
  return val
end


HALFPI = math.pi * 0.5;
TWOPI = math.pi * 2;

function angleOf( v )
  local rad = TWOPI - math.atan2( v.y, v.x )
  while rad < 0 do rad = rad + TWOPI end
  while rad > TWOPI do rad = rad - TWOPI end
  return rad
end




--------------------- 2D Vector Class ---------------------

vec = class("vec")

function vec:initialize(xx,yy)
  self.x = xx
  self.y = yy
end

function vec:__unm()
  return vec( -self.x , -self.y )
end

function vec:__add( v2 )
  return vec( v2.x + self.x, v2.y + self.y )
end

function vec:__sub( v2 )
  return vec( self.x - v2.x , self.y - v2.y )
end


function vec:__mul( r )
  return vec( self.x * r , self.y * r )
end


function vec:__eq(  v2 )
  return zero( self.x - v2.x ) and zero( self.y - v2.y );
end

function vec:dot( v2 )
  return self.x*v2.x +self.y*v2.y
end

function vec:scale( N )
  return vec( self.x*N, self.y*N )
end

function vec:length( )
  return math.sqrt( self.x * self.x  + self.y * self.y )
end

function vec:abs() return vec( math.abs( self.x ), math.abs( self.y ) ) end

function vec:unit()  
  local d = self:length()
  if zero(d) then return vec(0,0) end
  return vec( self.x / d, self.y / d )
end

function vec:normalize() return self:unit() end

function vec:distanceTo( v2 )
  return (v2 - self):length()
end

function midpoint( v, v2 )
  local dx = ( v2.x - v.x ) * 0.5;
  local dy = ( v2.y - v.y ) * 0.5;
  return vec( v.x + dx, v.y + dy );
end

function vec:__tostring( )
  return string.format( "<%0.2f, %0.2f>", self.x, self.y )
end

function polar( r, len )
  len = len or 1
  return vec( math.cos(r) * len, math.sin(r) * len )
end


--------------------- Rectangle Class ---------------------

Rect = class('Rect')

function Rect:initialize( x, y, w, h )
  self.x = x
  self.y = y
  self.w = w
  self.h = h
end

function Rect:__tostring( )
  return string.format( "[%0.2f,%0.2f, %0.2f, %0.2f]", self.x, self.y, self.w, self.h )
end

function Rect:x2() return self.x + self.w end
function Rect:y2() return self.y + self.h end

function Rect:center() return vec( self.x + (self.w/2), self.y + (self.h/2) ) end

function Rect:moveTo(x,y) self.x = x; self.y = y; return self end
function Rect:moveTo(x,y) self.x = x; self.y = y; return self end
function Rect:resize(w,h) self.w = w; self.h = h; return self end

function Rect:values() return self.x, self.y, self.w, self.h end
function Rect:coords() return self.x, self.y, self.x + self.w, self.y, self.x + self.w, self.y + self.h, self.x, self.y + self.h end

function Rect:inset( n ) return Rect:new( self.x + n, self.y + n, self.w - (n*2), self.h - (n*2) ) end

function Rect:constrain( v )
  v.x = math.max( v.x, self.x )
  v.y = math.max( v.y, self.y )
  v.x = math.min( v.x, self.x + self.w )
  v.y = math.min( v.y, self.y + self.h )
end

function Rect:intersects( r )
  return instanceOf( Rect, r ) and
         r.x >= self.x and
         r.y >= self.y and
         r:x2() <= self:x2() and
         r:y2() <= self:y2()
end

function Rect:intersectsCircle( pos, radius )
  return pos.y + radius >= self.y and
         pos.y - radius <= self:y2() and
         pos.x + radius >= self.x and
         pos.x - radius <= self:x2() 
end


function Rect:contains( x, y )
  if instanceOf(vec,x) then x, y = x.x, x.y end
  return x>=self.x and x<=(self.x+self.w) and y>=self.y and y<=(self.y+self.h)
end

--------------------- Other stuff ---------------------

function walkRight( P, Q, items )
  local nextX = math.floor( P.x ) + 1
  local r = (Q - P);
  local delta = r.y / r.x ;
  print( "Delta Right ", delta )
  while nextX <= Q.x do
    local nextY = P.y + ( ( nextX - P.x ) * delta );
    items:append( vec( nextX, nextY ) )
    nextX = nextX + 1
  end
end

function walkUp( P, Q, items )
  local nextY = math.floor( P.y ) + 1
  local r = (Q - P);
  local delta = r.x / r.y ;
  print( "Delta UP", delta )
  while nextY <= Q.y do
    local nextX = P.x + ( ( nextY - P.y ) * delta );
    items:append( vec(  nextX, nextY ) )
    nextY = nextY + 1
  end
end

function walkGrid( P, Q, f )
  local items = List()
  local angle = angleOf( Q-P )
  local C, S = math.cos( angle ), math.sin(angle)
  if C>0 then  walkRight( P, Q, items )
  elseif C<0 then walkLeft( P, Q, items ) end
  
  if S>0 then walkUp( P, Q, items )
  elseif S<0 then walkUp( P, Q, items ) end

  return items:sortBy( function(v) local q = P-v; print(q) ;return q:dot(q) end ):each( f )
end

function gridTest()
  P = vec( 1,1 )
  Q = vec( 8,7 )
  
  walkGrid( P, Q, function( v ) print( v ) end )
end
