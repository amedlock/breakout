require("middleclass")
require("vectors")


--------------------- A Shape is portion of a bitmap ---------------------

Shape = class("Shape") 

function Shape:initialize( image, x, y, w, h )
  if type(image)=="string" then 
    image = love.graphics.newImage( image )
  end
  self.image = image
  if x==nil then x,y = 0,0 end
  if w==nil then w,h = image:getWidth(), image:getHeight() end
  self.quad = love.graphics.newQuad( x, y, w, h, image:getWidth(), image:getHeight() )
  self.width = w
  self.height = h
end

--------------------- A Sprite is a scaled Shape ---------------------

Sprite = class("Sprite")

-- add offset to this

function Sprite:initialize(shape, size)

  if type(shape)=="string" then
    local img = love.graphics.newImage( shape )
    shape = Shape( img )
  end
  assert( instanceOf( Shape, shape ) )  -- sanity check
  self.shape = shape
  if size==nil then size = vec( shape.width, shape.height ) elseif type(size)=='number' then size= vec( size,size ) end
  self.size = size
  self.scale = vec( size.x / self.shape.width , size.y / self.shape.height  )
end

function Sprite:draw(pos, rot)
  local R = math.rad( rot or 0 )
  love.graphics.drawq( self.shape.image, self.shape.quad, pos.x, pos.y, R, self.scale.x, self.scale.y )
end

