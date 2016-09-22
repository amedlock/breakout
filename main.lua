require( "util" ) 
require( "vectors" )
require( "sprites" )

local sounds = {}

local font = nil
local screen = {}

local ballImage = nil

local balls = List() -- more than one!
local prizes = List()
local vanish = List()


local steelBrick = nil
local brickShapes = List() -- list of brick shapes
local prizeShapes = List() -- list of falling prize shapes
local vanishSprite = nil
local paddle = nil
local board = nil


local gameMode = nil -- start, play, stop
local messages = { start='Breakout - Press any key to start', stop='Game Over - Press any key to restart', nextLevel="Next Map Starting..." }


local boardPos = vec( 20, 10 )
local paddleSpeed = 600.0;
local brickSize = vec( 42, 20 )
local ballStart = vec( 30, 250 )
local ballAngle = 45


local ballTimer = nil
local score = 0
local ballCount = 3
local stage = 1

local levelTimer = nil

local bricksRemaining = 0;


Brick = class("Brick")
function Brick:initialize( x, y, color, special )
  self.pos = vec( x,y )
  self.bounds = Rect( x, y, brickSize.x, brickSize.y )
  self.solid = true
  self.special = special
  if special then color = color + 5 end
  if math.random( 1,35 )==17 then
    self.steel = true
    self.special = false
    self.hits = 10
    self.sprite = Sprite( steelBrick, vec(brickSize.x-1, brickSize.y-1) ) -- we could also mixin the sprite class
  else
    self.sprite = Sprite( brickShapes[ color ], vec(brickSize.x-1, brickSize.y-1) ) -- we could also mixin the sprite class
  end  
end

function Brick:draw()  if self.solid then self.sprite:draw(self.pos) end end


Board = class("Board")
function Board:initialize( w,h )
  self.width = w
  self.height = h
  self.pos = vec(20,10)
  
  self.grid = List()  -- bricks
  iterate( 1, w, function( x ) 
    iterate( 1, h, function( y) 
      local xp = self.pos.x + ( brickSize.x * ( x - 1 ) )
      local yp = self.pos.y + ( brickSize.y * ( y - 1 ) )
      local br = Brick( xp, yp, math.random(1,5), math.random( 1,10 ) > 7)
      self.grid:append( br ) 
      if br.solid and not br.steel then bricksRemaining = bricksRemaining + 1 end      
    end )
  end )
end

function Board:draw()
  self.grid:each( function( br ) br:draw( ) end )
end

function Board:overlaps( pos, radius )  -- which bricks overlap the circle described by pos, radius
  return self.grid:filter( function(br)
    if not br.solid then return false end
    if pos.x + radius < br.pos.x or pos.x - radius > br.pos.x + brickSize.x then return false end
    return pos.y + radius > br.pos.y and pos.y - radius < br.pos.y + brickSize.y
  end )
end


Prize = class("Prize")
function Prize:initialize( num, x, y, speed )
  self.sprite = Sprite( prizeShapes[ num ], brickSize )
  self.amount = num * 100
  self.pos = vec( x,y )
  self.speed = speed
end

function Prize:draw()
  self.sprite:draw( self.pos, 0 )
end


Paddle = class("Paddle")
function Paddle:initialize( shape )
  self.pos = vec( 15, screen.height - 130 ) ;
  self.sprite = Sprite( shape, vec( 50, 10 ) )
end

function Paddle:center()
  return self.pos + self.sprite.size:scale( 0.5 )
end

function Paddle:left(amt)
  self.movement= 'left'
  self.pos.x = clamp( self.pos.x - amt, screen.left, screen.right - self.sprite.size.x )
end

function Paddle:right(amt)
  self.movement= 'left'
  self.pos.x = clamp( self.pos.x + amt, screen.left, screen.right - self.sprite.size.x )
end

function Paddle:draw()
  self.sprite:draw( self.pos )
end

function Paddle:touches(p)
  if p.pos.y + brickSize.y < self.pos.y then return false end
  if p.pos.x + brickSize.x < self.pos.x then return false end
  return self.pos.x + self.sprite.size.x > p.pos.x
end

function Paddle:hits(B)
  if B.velocity.y < 0 then return false end  -- fix wonky update errors
  
  local bp = B:center()
  local bs = B.size
  local ps = self.sprite.size;
  
  -- I should use a generic box-circle collision method
  
  if not Rect( self.pos.x, self.pos.y, self.sprite.size.x, self.sprite.size.y ):intersectsCircle( bp, B.size ) then  return false end
  
  -- if B.pos.y + B.size < self.pos.y then return false 
  -- elseif B.pos.y > self.pos.y + self.sprite.size.y then return false 
  -- elseif B.pos.x + B.size < self.pos.x then return false 
  -- elseif B.pos.x > self.pos.x + self.sprite.size.x then return false end
  
  local d_angle =90
  if self.movement=="left" then d_angle = 90 - math.random( 1,20 )
  elseif self.movement=="right" then d_angle = 90 + math.random( 1,20 ) end
  
  B:deflect( -polar( math.rad( d_angle ), 1 ) )
  
  local ball_angle = angleOf( B.velocity );
  local r20 = math.rad( 20 )
  local r160 = math.rad( 160 )
  if ball_angle < r20 or  ball_angle > r160 then
    ball_angle = clamp( ball_angle, r20, r160 )
    B.velocity = polar( ball_angle, B.speed )
  end
  if B.velocity.y > 0 then B.velocity = -B.velocity end
  B.pos.y = self.pos.y - ( B.size + 1 ) 
  B.lastHit = nil
  return true
end


Ball = class("Ball")

function Ball:initialize( pos, dir )
  self.shape = Shape( ballImage )
  self.sprite = Sprite( self.shape, 12 )
  self.size = 12
  self.speed = 0.25 
  self.reset = function() self.pos = pos; self.velocity = polar( math.rad(dir) ,self.speed ); self.lastHit = nil end 
  self.reset()
end


function Ball:center() return self.pos + self.sprite.size:scale( 0.5 ) end
function Ball:bounds() return Rect( self.pos.x, self.pos.y, self.sprite.size.x, self.sprite.size.y ) end

function Ball:distanceTo( br )
  local base = ( self.pos - boardPos ) - br.pos 
  return base:length()
end

function Ball:deflect( N )
  local D = N:dot( self.velocity )
  local U = (self.velocity - (N * 2):scale( D ) ):unit()
  self.velocity = U:scale( self.speed )
end

function Ball:update(dt)
  local p = self.pos + self.velocity
  
  if p.x < screen.left then self:deflect( vec( 1,0 ) )
  elseif p.x > screen.right then self:deflect( vec(-1,0 ) ) end
  
  if p.y < screen.top then self:deflect( vec( 0,1 ) )
  elseif p.y > screen.bottom then self:deflect( vec(0, -1) ) end
  
  self.pos = self.pos + self.velocity
end


function Ball:draw()
  love.graphics.setColor( 255,255,255,255 )
  self.sprite:draw( self.pos, 0 )
end


function startGame()
  gameMode='play'
  score=0
  stage=1
  ballCount = 3  
end

function stopGame()
  gameMode='stop'
end

function resetGame()
  board:initialize(board.width, board.height)
  balls = List()
  ballTimer = 3
  gameMode = 'start'
end

function resetLevel()
  board:initialize(board.width, board.height)
  balls = List()
  ballTimer = 3
  gameMode = 'start'
end


function love.load()
  font = love.graphics.newFont( "arialbd.ttf", 18)
  love.graphics.setFont(font)
  
  love.graphics.setColorMode( "replace" )
  
  screen.width = love.graphics.getWidth()
  screen.height = love.graphics.getHeight()
  screen.left, screen.top,  screen.right , screen.bottom= 5,10, 790, 500
  
  ballImage = love.graphics.newImage( "ball.png" )

  local steelImage = love.graphics.newImage( "steelbrick.png" );
  steelBrick = Shape( steelImage )
  
  local brickImage = love.graphics.newImage( love.image.newImageData( "bricks.png" ) )
  local addBrickShape = function( x, y1, y2 )
    brickShapes:append( Shape( brickImage, x, y1, 210, (y2-y1)+1 ) )
  end
  
  iterate( 0, 1, function(px)
    local pxx = px * 212
    addBrickShape(pxx, 0, 99)
    addBrickShape(pxx, 99, 201)
    addBrickShape(pxx,202, 301)
    addBrickShape(pxx,306, 405)
    addBrickShape(pxx,411, 510)
  end )
  
  
  
  paddle = Paddle( "paddle.png", vec( 16, 12 ) )
  
  prizeShapes:append( Shape( "prize_100.png" ) )
  prizeShapes:append( Shape( "prize_200.png" ) )
  prizeShapes:append( Shape( "prize_300.png" ) )
  
  board = Board(16, 10)
  
  resetGame()  
  
  vanishSprite = Sprite( "brick_vanish.png", brickSize );
  
  sounds.clink = love.audio.newSource( "clink.wav" )
  sounds.lostball = love.audio.newSource( "lostball.wav" )
  sounds.powerup = love.audio.newSource( "powerup.wav" )
  sounds.newlife = love.audio.newSource( "newlife.wav" )
  sounds.hit = love.audio.newSource( "clink.wav" ) --love.audio.newSource( "hit.wav" )
  
  print( polar( math.rad( 0 ),1 ) )
  print( polar( math.rad( 45 ),1 ) )
  print( polar( math.rad( 90 ),1 ) )
  print( polar( math.rad( 180 ),1 ) )
  
  gridTest()
end


function drawUI()
    love.graphics.setColor( 255,255,255,255 )
    local ty = screen.height - ( font:getHeight() + 6 )
    love.graphics.print( string.format("Score:%d Level:%d Balls:%d", score,stage,ballCount ), 20, ty )
    
    local msg2 = "Press F10 to exit, F12 to restart"
    if ballTimer then msg2 = string.format( "Next ball in %d seconds", ballTimer ) end
    
    local tsize = font:getWidth( msg2 ) + 15
    love.graphics.setColor( 255,255,25, 255 )
    love.graphics.print( msg2, screen.width - tsize, ty )
    love.graphics.rectangle( "line", 99,0, 20 * board.width, 20 * board.height )
end

function drawMenu()
  local msg = messages[ gameMode ]
  if not msg then return end
  
  if not font then return end
  local margin = 20
  
  love.graphics.setColor( 255,255,255,255 )
  local tw = font:getWidth( msg )
  local th = font:getHeight()
  local left = ( screen.width /2 ) - ( tw/ 2 )
  local top  = ( screen.height / 2 ) - ( th / 2 )
  love.graphics.print( msg, left , top )
  love.graphics.rectangle( "line", left - (margin/2), top - (margin/2), tw + margin, th + margin )
end

function love.draw() 

  if gameMode=='play' or gameMode=='stop' then
    love.graphics.setColor( 255,255,255,255 )
    drawUI()
    board:draw()
    balls:each( function(B) B:draw() end )
    paddle:draw()
    prizes:each( function(pr) pr:draw() end )
    vanish:each( function(v) 
      love.graphics.setColor( 255,255,255,v.alpha )
      vanishSprite:draw( v.pos )
    end )
  end
  
  if gameMode=='start' or gameMode=='stop'  or gameMode=='nextLevel' then
    drawMenu()
  end
end


function love.keypressed( k, u )
  if k=="f10" then 
    love.event.push("quit") 
  end
  
  if gameMode=='start' then
    startGame()
    return
  elseif gameMode=='stop' then
    resetGame()
    return
  end
  
  if k=="f12" then
    stopGame()
    return
  end
end

function love.mousepressed( mx,my,b )
end
  
function love.mousereleased( x,y,b )
end

function love.keyreleased( k )
end


function findNormalToBrick( B,brick )
    local c = B:center()
    local bb = brick.bounds
    
    local leftSide = c.x < bb.x and ( c.x + B.size >= bb.x )
    local rightSide = c.x > bb:x2() and c.x - B.size <= bb:x2()
    local topSide = c.y < bb.y and c.y + B.size >= bb.y
    local bottomSide = c.y > bb:y2() and c.y - B.size < bb:y2()
    
    if bottomSide then
      return vec( 0, 1 )
    end
    if leftSide then
      return vec( -1, 0 ) 
    end
    if rightSide then
      return vec( 1,0 ) 
    end
    if topSide then
      return vec( 0, -1 )
    end
    
    return nil;    
end

function addBall( pos, dir )
  if dir==nil then dir = math.random( 15, 75 ) end
  local nb = Ball( pos, dir )
  balls:append( nb ) 
end

function addVanish( pos, dur )
  vanish:append( { pos=pos,  duration = dur, alpha= 40 } )
end

function addPrize( num, pos )
  prizes:append( Prize( num, pos.x, pos.y, 40 + ( math.random(2,5)* 5 ) ) )
end

function addSpecial( brick )
  if #balls < 2 and math.random(1,12)==12 then
    addBall(brick.pos + vec(0,10) )
    return
  end
  local k = math.random( 1, 10 )
  if k < 2 then addPrize( 3, brick.pos ) 
  elseif k < 5 then addPrize( 2, brick.pos ) 
  else addPrize( 1, brick.pos ) end
end


function handleBallCollision(B)
  local ballCenter = B:center()
  local brick = board:overlaps( ballCenter, B.size ):sortBy( function(br) return B:distanceTo( br ) end ):findWhere( function(br) return br~=B.lastHit end )
  if brick then 
    local N = findNormalToBrick( B, brick )
    if N then 
      B.lastHit = brick
      B:deflect( N ) 
      if not sounds.hit:isStopped() then sounds.hit:rewind() else  sounds.hit:play() end
      if not brick.steel then 
        brick.solid = false         
        bricksRemaining = bricksRemaining - 1
        score = score + 10
        if brick.special then 
          addSpecial( brick ) 
        else
          addVanish( brick.pos, 0.6 )
        end
      else
        brick.hits = brick.hits - 1
        if brick.hits < 1 then brick.solid = false end
      end
    end
  end
end


function love.update(dt)

  if gameMode=="nextLevel" then
    levelTimer = levelTimer + dt
    if levelTimer > 3 then 
      board:initialize( board.width, board.height )
      balls = List()
      ballCount = ballCount + 1
      levelTimer = nil
      gameMode = 'play'
      ballTimer = 3
      return
    end
  end
  
  if gameMode~='play' then return end
  
  if bricksRemaining<=0 then gameMode = 'nextlevel' end
  
  if ballTimer then 
    ballTimer = ballTimer - dt 
    if ballTimer <= 0 then 
      ballTimer = nil
      ballCount = ballCount - 1
      addBall( ballStart )
    end
  end
      
  
  if love.keyboard.isDown("left") then paddle:left( dt * paddleSpeed )
  elseif love.keyboard.isDown("right") then paddle:right( dt * paddleSpeed ) 
  else paddle.movement= nil end

  local bottomY = paddle.pos.y + paddle.sprite.size.y + 10 
  
  prizes:each( function( p )  
    if paddle:touches( p ) then 
      score = score + p.amount
      p.pos.y = bottomY + 50
      sounds.powerup:play()
    else
      p.pos = p.pos + vec( 0, dt * p.speed ) 
    end
  end )

  vanish:each( function( v ) v.duration = v.duration - dt; v.alpha = v.alpha * 0.5 end )
  vanish = vanish:filter( function(v) return v.duration > 0 end )
  
  prizes = prizes:filter( function(pr) return pr.pos.y < bottomY end )
  balls:each( function (B)
    B:update( dt )
    if paddle:hits(B) then
      if not sounds.clink:isStopped() then sounds.clink:rewind() else  sounds.clink:play() end
    else
      handleBallCollision( B )
      --if handleBallCollision( B ) then sounds.hit:play() end
    end
  end )
  
  if not ballTimer then
    local bc = #balls
    balls = balls:filter( function( B ) return B.pos.y < bottomY end )
    if #balls ~= bc then sounds.lostball:play() end
    if #balls<1 then
      if ballCount>0 then ballTimer = 2.0 else gameMode ='stop' end
    end
  end
end

