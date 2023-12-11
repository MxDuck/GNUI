--[[______   __                _                 __
  / ____/ | / /___ _____ ___  (_)___ ___  ____ _/ /____  _____
 / / __/  |/ / __ `/ __ `__ \/ / __ `__ \/ __ `/ __/ _ \/ ___/
/ /_/ / /|  / /_/ / / / / / / / / / / / / /_/ / /_/  __(__  )
\____/_/ |_/\__,_/_/ /_/ /_/_/_/ /_/ /_/\__,_/\__/\___/____]]

--[[ NOTES
Everything is in one file to make sure it is possible to load this script from a config file, 
allowing me to put as much as I want without worrying about storage space.
]]

local main = {}

local config = {
   debug_visible = true,
   debug_event_name = "__c",
   internal_events_name = "__a",
}

--#region EventLib
local eventLib = {}

---@class EventLib
local eventMetatable = {__type = "Event", __index = {}}
local eventsMetatable = {__index = {}}
eventMetatable.__index = eventMetatable

---@return EventLib
function eventLib.new()
   return setmetatable({subscribers = {}}, eventMetatable)
end
---@return EventLib
function eventLib.newEvent()
   return setmetatable({subscribers = {}}, eventMetatable)
end

function eventLib.table(tbl)
   return setmetatable({_table = tbl or {}}, eventsMetatable)
end

---Registers an event
---@param func function
---@param name string?
function eventMetatable:register(func, name)
   if name then
      self.subscribers[name] = {func = func}
   else
      table.insert(self.subscribers, {func = func})
   end
end

---Clears all event
function eventMetatable:clear()
   self.subscribers = {}
end

---Removes an event with the given name.
---@param match string
function eventMetatable:remove(match)
   self.subscribers[match] = nil
end

---Returns how much listerners there are.
---@return integer
function eventMetatable:getRegisteredCount()
   return #self.subscribers
end

function eventMetatable:__call(...)
   local returnValue = {}
   for _, data in pairs(self.subscribers) do
      table.insert(returnValue, {data.func(...)})
   end
   return returnValue
end

function eventMetatable:invoke(...)
   local returnValue = {}
   for _, data in pairs(self.subscribers) do
      table.insert(returnValue, {data.func(...)})
   end
   return returnValue
end

function eventMetatable:__len()
   return #self.subscribers
end

-- events table
function eventsMetatable.__index(t, i)
   return t._table[i] or (type(i) == "string" and getmetatable(t._table[i:upper()]) == eventMetatable) and t._table[i:upper()] or nil
end

function eventsMetatable.__newindex(t, i, v)
   if type(i) == "string" and type(v) == "function" and t._table[i:upper()] and getmetatable(t._table[i:upper()]) == eventMetatable then
      t._table[i:upper()]:register(v)
   else
      t._table[i] = v
   end
end

function eventsMetatable.__ipairs(t)
   return ipairs(t._table)
end
function eventsMetatable.__pairs(t)
   return pairs(t._table)
end

--#endregion

--#region-->========================================[ Utilities ]=========================================<--

local utils = {}

---Returns the same vector but the `X` `Y` are the **min** and `Z` `W` are the **max**.  
---vec4(1,2,0,-1) --> vec4(0,-1,1,2)
---@param vec4 Vector4
---@return Vector4
function utils.vec4FixNegativeBounds(vec4)
   return vectors.vec4(
      math.min(vec4.x,vec4.z),
      math.min(vec4.y,vec4.w),
      math.max(vec4.x,vec4.z),
      math.max(vec4.y,vec4.w)
   )
end

---Sets the position`(x,y)` while translating the other position`(x,z)`
---@param vec4 Vector4
---@param x number
---@param y number
---@return Vector4
function utils.vec4SetPos(vec4,x,y)
   local lpos = vec4.xy
   vec4.x,vec4.y = x,y
   vec4.z,vec4.w = x-lpos.x,y-lpos.y
   return vec4
end

---Sets the other position`(x,z)` while translating the position`(x,y)`
---@param vec4 Vector4
---@param z number
---@param w number
---@return Vector4
function utils.vec4SetOtherPos(vec4,z,w)
   local lpos = vec4.zw
   vec4.z,vec4.w = z,w
   vec4.x,vec4.y = z-lpos.x,w-lpos.y
   return vec4
end

---Gets the size of a vec4
---@param vec4 Vector4
---@return Vector2
function utils.vec4GetSize(vec4)
   return (vec4.zw - vec4.xy) ---@type Vector2
end

function utils.figureOutVec2(posx,y)
   local typa, typb = type(posx), type(y)
   
   if typa == "Vector2" and typb == "nil" then
      return posx:copy()
   elseif typa == "number" and typb == "number" then
      return vectors.vec2(posx,y)
   else
      error("Invalid Vector2 parameter, expected Vector2 or (number, number), instead got ("..typa..", "..typb..")")
   end
end

function utils.figureOutVec3(posx,y,z)
   local typa, typb, typc = type(posx), type(y), type(z)
   
   if typa == "Vector2" and typb == "nil" and typc == "nil" then
      return posx:copy()
   elseif typa == "number" and typb == "number" and typc == "number" then
      return vectors.vec3(posx,y,z)
   else
      error("Invalid Vector3 parameter, expected Vector3 or (number, number, number), instead got ("..typa..", "..typb..", "..typc..")")
   end
end

--#endregion

--#region-->========================================[ Debug ]=========================================<--

local debug = {}
debug.texture = textures:newTexture("1x1white",1,1):setPixel(0,0,vectors.vec3(1,1,1))

--#endregion

--#region-->========================================[ SpriteRenderer ]=========================================<--

---@class Sprite
---@field Texture Texture
---@field TEXTURE_CHANGED EventLib
---@field Modelpart ModelPart?
---@field MODELPART_CHANGED EventLib
---@field UV Vector4
---@field Size Vector2
---@field Position Vector3
---@field Color Vector3
---@field Scale number
---@field DIMENSIONS_CHANGED EventLib
---@field RenderTasks table<any,SpriteTask>
---@field BorderThickness Vector4
---@field BORDER_THICKNESS_CHANGED EventLib
---@field id integer
local Sprite = {}
Sprite.__index = Sprite

local sprite_next_free = 0
---@return Sprite
function Sprite.new()
   local new = {}
   new.Texture = debug.texture
   new.TEXTURE_CHANGED = eventLib.new()
   new.MODELPART_CHANGED = eventLib.new()
   new.Position = vectors.vec3()
   new.UV = vectors.vec4(0,0,1,1)
   new.Size = vectors.vec2(16,16)
   new.Color = vectors.vec3(1,1,1)
   new.Scale = 4
   new.DIMENSIONS_CHANGED = eventLib.new()
   new.RenderTasks = {}
   new.BorderThickness = vectors.vec4(0,0,0,0)
   new.BORDER_THICKNESS_CHANGED = eventLib.new()
   new.id = sprite_next_free
   sprite_next_free = sprite_next_free + 1
   setmetatable(new,Sprite)
   
   new.TEXTURE_CHANGED:register(function ()
      new:_updateRenderTasks()
   end,config.internal_events_name)

   new.MODELPART_CHANGED:register(function ()
      new:_deleteRenderTasks()
      new:_buildRenderTasks()
   end,config.internal_events_name)

   new.BORDER_THICKNESS_CHANGED:register(function ()
      new:_deleteRenderTasks()
      new:_buildRenderTasks()
   end,config.internal_events_name)
   
   new.DIMENSIONS_CHANGED:register(function ()
      new:_updateRenderTasks()
   end,config.internal_events_name)

   return new
end

---Sets the modelpart to parent to.
---@param part ModelPart
---@return Sprite
function Sprite:setModelpart(part)
   self.Modelpart = part
   self.MODELPART_CHANGED:invoke(self.Modelpart)
   return self
end


---Sets the displayed image texture on the sprite.
---@param texture Texture
---@return Sprite
function Sprite:setTexture(texture)
   self.Texture = texture
   local dim = texture:getDimensions()
   self.UV = vectors.vec4(0,0,dim.x,dim.y)
   self.TEXTURE_CHANGED:invoke(self,self.Texture)
   return self
end

---Sets the position of the Sprite, relative to its parent.
---@param xpos number
---@param y number
---@param depth number?
---@return Sprite
function Sprite:setPos(xpos,y,depth)
   self.Position = utils.figureOutVec3(xpos,y,depth or 0)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---Tints the Sprite multiplicatively
---@param rgb number|Vector3
---@param g number?
---@param b number?
---@return Sprite
function Sprite:setColor(rgb,g,b)
   self.Color = utils.figureOutVec3(rgb,g,b)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---Sets the size of the sprite duh.
---@param xpos number
---@param y number
---@return Sprite
function Sprite:setSize(xpos,y)
   self.Size = utils.figureOutVec2(xpos,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---@param scale number
---@return Sprite
function Sprite:setScale(scale)
   self.Scale = scale
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

-->====================[ Border ]====================<--

---Sets the top border thickness.
---@param units number?
---@return Sprite
function Sprite:setBorderThicknessTop(units)
   self.BorderThickness.y = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the left border thickness.
---@param units number?
---@return Sprite
function Sprite:setBorderThicknessLeft(units)
   self.BorderThickness.x = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the down border thickness.
---@param units number?
---@return Sprite
function Sprite:setBorderThicknessDown(units)
   self.BorderThickness.z = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the right border thickness.
---@param units number?
---@return Sprite
function Sprite:setBorderThicknessRight(units)
   self.BorderThickness.w = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the padding for all sides.
---@param left number?
---@param top number?
---@param right number?
---@param bottom number?
---@return Sprite
function Sprite:setBorderThickness(left,top,right,bottom)
   self.BorderThickness.x = left   or 0
   self.BorderThickness.y = top    or 0
   self.BorderThickness.z = right  or 0
   self.BorderThickness.w = bottom or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the UV region of the sprite, a and b are relative to the top left to the bottom right
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return Sprite
function Sprite:setUV(ax,ay,bx,by)
   self.UV = vectors.vec4(ax,ay,bx,by)
   self.BORDER_THICKNESS_CHANGED:invoke(self.BorderThickness)
   return self
end

function Sprite:_deleteRenderTasks()
   for _, task in pairs(self.RenderTasks) do
      self.Modelpart:removeTask(task:getName())
   end
   return self
end

function Sprite:_buildRenderTasks()
   local b = self.BorderThickness
   self.is_ninepatch = not (b.x == 0 and b.y == 0 and b.z == 0 and b.w == 0)
   if not self.is_ninepatch then -- not 9-Patch
      self.RenderTasks[1] = self.Modelpart:newSprite("patch"..self.id)
   else
      self.RenderTasks = {
         self.Modelpart:newSprite("patch_tl"..self.id),
         self.Modelpart:newSprite("patch_t"..self.id),
         self.Modelpart:newSprite("patch_tr"..self.id),
         self.Modelpart:newSprite("patch_ml"..self.id),
         self.Modelpart:newSprite("patch_m"..self.id),
         self.Modelpart:newSprite("patch_mr"..self.id),
         self.Modelpart:newSprite("patch_bl"..self.id),
         self.Modelpart:newSprite("patch_b"..self.id),
         self.Modelpart:newSprite("patch_br"..self.id)
      }
   end
   self:_updateRenderTasks()
end

function Sprite:_updateRenderTasks()
   local dim = self.Texture:getDimensions()
   local uv = self.UV:copy():add(0,0,1,1)
   if not self.is_ninepatch then
      self.RenderTasks[1]
      :setTexture(self.Texture)
      :setPos(self.Position)
      :setScale(self.Size.x/dim.x,self.Size.y/dim.y)
      :setColor(self.Color)
   else
      local border = self.BorderThickness*self.Scale
      local uvborder = self.BorderThickness
      local pos = self.Position
      local size = self.Size
      local uvsize = vectors.vec2(uv.z-uv.x,uv.w-uv.y)
      for _, task in pairs(self.RenderTasks) do
         task
         :setTexture(self.Texture)
         :setColor(self.Color)
         :setUVPixels(
            uv.x,
            uv.y
         )
         :region(
            uv.z,
            uv.w
         )
      
      end
      self.RenderTasks[1]
      :setPos(
         pos
      ):setScale(
         border.x/dim.x,
         border.y/dim.y
      ):setUVPixels(
         uv.x,
         uv.y
      ):region(
         uvborder.x,
         uvborder.y
      )
      
      self.RenderTasks[2]
      :setPos(
         pos.x-border.x,
         pos.y,
         pos.z
      ):setScale(
         (size.x-border.z-border.x)/dim.x,
         border.y/dim.y
      ):setUVPixels(
         uv.x+uvborder.x,
         uv.y
      ):region(
         uvsize.x-uvborder.x-uvborder.z,
         uvborder.y
      )
      self.RenderTasks[3]
      :setPos(
         -size.x+border.z,
         -pos.y,
         pos.z
      ):setScale(
         border.z/dim.x,border.y/dim.y
      ):setUVPixels(
         uv.z-uvborder.x-1,
         uv.y
      ):region(
         uvborder.z,
         uvborder.y
      )

      self.RenderTasks[4]
      :setPos(
         pos.x,
         pos.y-border.y,
         pos.z
      )
      :setScale(
         border.x/dim.x,
         (size.y-border.y-border.w)/dim.y
      ):setUVPixels(
         uv.x,
         uv.y+uvborder.y
      ):region(
         uvborder.x,
         uvsize.y-uvborder.y-uvborder.w
      )
      
      self.RenderTasks[5]
      :setPos(
         pos.x-border.x,
         pos.y-border.y,
         pos.z
      )
      :setScale(
         (size.x-border.x-border.z)/dim.x,
         (size.y-border.y-border.w)/dim.y
      ):setUVPixels(
         uv.x+uvborder.x,
         uv.y+uvborder.y
      ):region(
         uvsize.x-uvborder.x-uvborder.z,
         uvsize.y-uvborder.y-uvborder.w
      )

      self.RenderTasks[6]
      :setPos(
         pos.x-size.x+border.z,
         pos.y-border.y,
         pos.z
      )
      :setScale(
         border.z/dim.x,
         (size.y-border.y-border.w)/dim.y
      ):setUVPixels(
         uv.z-uvborder.z,
         uv.y+uvborder.y
      ):region(
         uvborder.z,
         uvsize.y-uvborder.y-uvborder.w
      )
      
      
      self.RenderTasks[7]
      :setPos(
         -pos.x,
         -size.y+border.w,
         pos.z
      )
      :setScale(
         border.x/dim.x,
         border.w/dim.y
      ):setUVPixels(
         uv.x,
         uv.w-uvborder.w
      ):region(
         uvborder.x,
         uvborder.w
      )

      self.RenderTasks[8]
      :setPos(
         -pos.x-border.x,
         -size.y+border.w,
         pos.z
      )
      :setScale(
         (size.x-border.z-border.x)/dim.x,
         border.w/dim.y
      ):setUVPixels(
         uv.x+uvborder.x,
         uv.w-uvborder.w
      ):region(
         uvsize.x-uvborder.x-uvborder.z,
         uvborder.w
      )

      self.RenderTasks[9]
      :setPos(
         -size.x+border.z,
         -size.y+border.w,
         pos.z
      )
      :setScale(
         border.z/dim.x,
         border.w/dim.y
      ):setUVPixels(
         uv.z-uvborder.z,
         uv.w-uvborder.w
      ):region(
         uvborder.z,
         uvborder.w
      )
   end
end

--#endregion

--#region Element

local element_next_free = 0
---@class GNUI.element
---@field Visible boolean
---@field VISIBILITY_CHANGED EventLib
---@field Children table<any,GNUI.element|GNUI.element.container>
---@field ChildrenIndex integer
---@field CHILDREN_CHANGED table
---@field Parent GNUI.element|GNUI.element.container
---@field PARENT_CHANGED table
---@field ON_FREE EventLib
---@field id EventLib
local element = {}
element.__index = function (t,i)
   return rawget(t,i)
end
element.__type = "GNUI.element"

---Creates a new basic element.
---@param preset table?
---@return GNUI.element
function element.new(preset)
   local new = preset or {}
   new.Visible = true
   new.VISIBILITY_CHANGED = eventLib.new()
   new.Children = {}
   new.ChildIndex = 0
   new.CHILDREN_CHANGED = eventLib.new()
   new.PARENT_CHANGED = eventLib.new()
   new.ON_FREE = eventLib.new()
   new.id = element_next_free
   setmetatable(new,element)
   element_next_free = element_next_free + 1
   return new
end

function element:updateChildrenOrder()
   for i, c in pairs(self.Children) do
      c.ChildrenIndex = i
   end
   return self
end

---Adopts an element as its child.
---@param child GNUI.element
---@param order integer?
---@return GNUI.element
function element:addChild(child,order)
   order = order or #self.Children+1
   table.insert(self.Children,order,child)
   self:updateChildrenOrder()
   child.Parent = self
   child.PARENT_CHANGED:invoke(self)
   return self
end

---Abandons the child.
---@param child GNUI.element
---@return GNUI.element
function element:removeChild(child)
   if child.Parent == self then -- check if the parent is even the one registered in the child's birth certificate
      self.Children[child.ChildrenIndex] = nil -- lmao
      child.Parent = nil
      child.ChildrenIndex = 0
      child.PARENT_CHANGED:invoke(nil)
   end
   self:updateChildrenOrder()
   return self
end

---Frees all the data of the element. all thats left to do is to forget it ever existed.
function element:free()
   if self.Parent then
      self.Parent:removeChild(self)
   end
   self.ON_FREE:invoke()
end

--#endregion

--#region-->========================================[ Container ]=========================================<--

---@class GNUI.element.container : GNUI.element
---@field Dimensions Vector4
---@field ContainmentRect Vector4
---@field DIMENSIONS_CHANGED EventLib
---@field Margin Vector4
---@field MARGIN_CHANGED EventLib
---@field Padding Vector4
---@field PADDING_CHANGED EventLib
---@field Anchor Vector4
---@field ANCHOR_CHANGED EventLib
---@field Part ModelPart
local container = {}
container.__index = function (t,i)
   return container[i] or element[i]
end

container.__type = "GNUI.element.container"

---Creates a new container.
---@param preset GNUI.element.container?
---@return GNUI.element.container
function container.new(preset)
   local new = preset or element.new()
   setmetatable(new,container)
   new.Dimensions = vectors.vec4(0,0,1,1)
   new.DIMENSIONS_CHANGED = eventLib.new()
   new.Margin = vectors.vec4()
   new.ContainmentRect = vectors.vec4()
   new.MARGIN_CHANGED = eventLib.new()
   new.Padding = vectors.vec4()
   new.PADDING_CHANGED = eventLib.new()
   new.Anchor = vectors.vec4(0,0,1,1)
   new.ANCHOR_CHANGED = eventLib.new()
   new.Part = models:newPart("container"..new.id)

   -->==========[ Internals ]==========<--

   new.DIMENSIONS_CHANGED:register(function ()
      new.ContainmentRect = vectors.vec4(0,0,
         (new.Dimensions.z - new.Padding.x - new.Padding.z - new.Margin.x - new.Margin.z),
         (new.Dimensions.w - new.Padding.y - new.Padding.w - new.Margin.y - new.Margin.w)
      )
      if new.Parent and new.Parent.ContainmentRect then
         local p = new.Parent.ContainmentRect
         local o = vectors.vec4(
            math.lerp(p.x,p.z,new.Anchor.x),
            math.lerp(p.y,p.w,new.Anchor.y),
            math.lerp(p.x,p.z,new.Anchor.z),
            math.lerp(p.y,p.w,new.Anchor.w)
         )
         new.ContainmentRect.x = new.ContainmentRect.y + o.x
         new.ContainmentRect.y = new.ContainmentRect.y + o.y
         new.ContainmentRect.z = new.ContainmentRect.z + o.z
         new.ContainmentRect.w = new.ContainmentRect.w + o.w
      end
      new.Part
      :setPos(
         -new.Dimensions.x-new.Margin.x-new.Padding.x,
         -new.Dimensions.y-new.Margin.y-new.Padding.y,-15)
      for key, value in pairs(new.Children) do
         if value.DIMENSIONS_CHANGED then
            value.DIMENSIONS_CHANGED:invoke(value.DIMENSIONS_CHANGED)
         end
      end
   end,config.internal_events_name)

   new.MARGIN_CHANGED:register(function ()
      new.DIMENSIONS_CHANGED:invoke(new.Dimensions)
   end,config.internal_events_name)

   new.PADDING_CHANGED:register(function ()
      new.DIMENSIONS_CHANGED:invoke(new.Dimensions)
   end,config.internal_events_name)

   new.PARENT_CHANGED:register(function ()
      new.Part:moveTo(new.Parent.Part)
   end)

   -->==========[ Debug ]==========<--

   if config.debug_visible then
      local debug_container = new.Part:newSprite("container"):texture(debug.texture):setColor(1,1,1)
      local debug_margin    = new.Part:newSprite("margin"):texture(debug.texture):setColor(1,0,0)
      local debug_padding   = Sprite.new():setModelpart(new.Part):setTexture(textures.ninepatch):setUV(3,2,12,12):setBorderThickness(2,2,3,4) -- :setColor(0,1,0)

      new.DIMENSIONS_CHANGED:register(function ()
         local contain = new.ContainmentRect
         local margin = new.Margin
         local padding = new.Padding
         debug_padding
         :setSize(
            contain.z - contain.x,
            contain.w - contain.y)
         :setPos(
            - contain.x,
            - contain.y,-0.6)
         
         debug_margin
         :pos(
            margin.x + padding.x - contain.x,
            margin.y + padding.y - contain.y,
            1)
         :scale(
            (contain.z - contain.x + margin.z + margin.x + padding.x + padding.z),
            (contain.w - contain.y + margin.w + margin.y + padding.y + padding.w),1)
         debug_container
         :pos(
            padding.x - contain.x,
            padding.y - contain.y,
            -0.3)
         :scale(
            (contain.z+padding.x+padding.z - contain.x),
            (contain.w+padding.y+padding.w - contain.y),1)
      end,config.debug_event_name)
   end
   return new
end

-->====================[ Dimensions ]====================<--

---Sets the position of the container, the size stays the same.
---@param xpos number|Vector2
---@param y number?
---@return GNUI.element.container
function container:setPos(xpos,y)
   self.Dimensions.xy = utils.figureOutVec2(xpos,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the size of the container
---@param xsize number|Vector2
---@param y number?
---@return GNUI.element.container
function container:setSize(xsize,y)
   self.Dimensions.zw = utils.figureOutVec2(xsize,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the position of the top left part of the container, the bottom right stays in the same position
---@param xpos number|Vector2
---@param y number?
---@return GNUI.element.container
function container:setTopLeft(xpos,y)
   local old,new = self.Dimensions.xy,utils.figureOutVec2(xpos,y)
   local delta = new-old
   self.Dimensions.xy,self.Dimensions.zw = new,self.Dimensions.zw - delta
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the position of the top left part of the container, the top left stays in the same position
---@param zpos number|Vector2
---@param w number?
---@return GNUI.element.container
function container:setBottomRight(zpos,w)
   local old,new = self.Dimensions.xy+self.Dimensions.zw,utils.figureOutVec2(zpos,w)
   local delta = new-old
   self.Dimensions.zw = self.Dimensions.zw + delta
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

-->====================[ Margins ]====================<--

---Sets the top margin.
---@param units number?
---@return GNUI.element.container
function container:setMarginTop(units)
   self.Margin.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left margin.
---@param units number?
---@return GNUI.element.container
function container:setMarginLeft(units)
   self.Margin.x = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down margin.
---@param units number?
---@return GNUI.element.container
function container:setMarginDown(units)
   self.Margin.z = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right margin.
---@param units number?
---@return GNUI.element.container
function container:setMarginRight(units)
   self.Margin.w = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the margin for all sides.
---@param left number?
---@param top number?
---@param right number?
---@param bottom number?
---@return GNUI.element.container
function container:setMargin(left,top,right,bottom)
   self.Margin.x = left   or 0
   self.Margin.y = top    or 0
   self.Margin.z = right  or 0
   self.Margin.w = bottom or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

-->====================[ Padding ]====================<--

---Sets the top padding.
---@param units number?
---@return GNUI.element.container
function container:setPaddingTop(units)
   self.Padding.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left padding.
---@param units number?
---@return GNUI.element.container
function container:setPaddingLeft(units)
   self.Padding.x = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down padding.
---@param units number?
---@return GNUI.element.container
function container:setPaddingDown(units)
   self.Padding.z = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right padding.
---@param units number?
---@return GNUI.element.container
function container:setPaddingRight(units)
   self.Padding.w = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the padding for all sides.
---@param left number?
---@param top number?
---@param right number?
---@param bottom number?
---@return GNUI.element.container
function container:setPadding(left,top,right,bottom)
   self.Padding.x = left   or 0
   self.Padding.y = top    or 0
   self.Padding.z = right  or 0
   self.Padding.w = bottom or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

-->====================[ Anchor ]====================<--

---Sets the top anchor.  
--- 0 = top part of the container is fully anchored to the top of its parent  
--- 1 = top part of the container is fully anchored to the bottom of its parent
---@param units number?
---@return GNUI.element.container
function container:setAnchorTop(units)
   self.Anchor.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left anchor.  
--- 0 = left part of the container is fully anchored to the left of its parent  
--- 1 = left part of the container is fully anchored to the right of its parent
---@param units number?
---@return GNUI.element.container
function container:setAnchorLeft(units)
   self.Anchor.x = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down anchor.  
--- 0 = bottom part of the container is fully anchored to the top of its parent  
--- 1 = bottom part of the container is fully anchored to the bottom of its parent
---@param units number?
---@return GNUI.element.container
function container:setAnchorDown(units)
   self.Anchor.z = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right anchor.  
--- 0 = right part of the container is fully anchored to the left of its parent  
--- 1 = right part of the container is fully anchored to the right of its parent  
---@param units number?
---@return GNUI.element.container
function container:setAnchorRight(units)
   self.Anchor.w = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the anchor for all sides.  
--- x 0 <-> 1 = left <-> right  
--- y 0 <-> 1 = top <-> bottom
---@param left number?
---@param top number?
---@param right number?
---@param bottom number?
---@return GNUI.element.container
function container:setAnchor(left,top,right,bottom)
   self.Anchor.x = left   or 0
   self.Anchor.y = top    or 0
   self.Anchor.z = right  or 0
   self.Anchor.w = bottom or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

--#endregion
main.newContainer = container.new
main.utils = utils
return main