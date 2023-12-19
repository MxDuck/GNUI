--[[______   __                _                 __
  / ____/ | / /___ _____ ___  (_)___ ___  ____ _/ /____  _____
 / / __/  |/ / __ `/ __ `__ \/ / __ `__ \/ __ `/ __/ _ \/ ___/
/ /_/ / /|  / /_/ / / / / / / / / / / / / /_/ / /_/  __(__  )
\____/_/ |_/\__,_/_/ /_/ /_/_/_/ /_/ /_/\__,_/\__/\___/____]]

--[[ NOTES
Everything is in one file to make sure it is possible to load this script from a config file, 
allowing me to put as much as I want without worrying about storage space.
]]

local api = {}

local config = {
   debug_visible = false,
   debug_scale = 0.4,
   
   clipping_margin = 0.1,
   
   debug_event_name = "_c",
   internal_events_name = "__a",
}

--#region EventLib
local eventLib = {}

---@class EventLib
local eventMetatable = { __type = "Event" }
local eventsMetatable = { __index = {}, __type = "Event" }
eventMetatable.__index = eventMetatable
eventMetatable.__type = "Event"
---@return EventLib
function eventLib.new()
   return setmetatable({ subscribers = {} }, eventMetatable)
end

---@return EventLib
function eventLib.newEvent()
   return setmetatable({ subscribers = {} }, eventMetatable)
end

function eventLib.table(tbl)
   return setmetatable({ _table = tbl or {} }, eventsMetatable)
end

---Registers an event
---@param func function
---@param name string?
function eventMetatable:register(func, name)
   if name then
      self.subscribers[name] = { func = func }
   else
      table.insert(self.subscribers, { func = func })
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
      table.insert(returnValue, { data.func(...) })
   end
   return returnValue
end

function eventMetatable:invoke(...)
   local returnValue = {}
   for _, data in pairs(self.subscribers) do
      table.insert(returnValue, { data.func(...) })
   end
   return returnValue
end

function eventMetatable:__len()
   return #self.subscribers
end

-- events table
function eventsMetatable.__index(t, i)
   return t._table[i] or
   (type(i) == "string" and getmetatable(t._table[i:upper()]) == eventMetatable) and
   t._table[i:upper()] or nil
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


function utils.deepCopy(original)
	local copy = {}
   local meta = getmetatable(original)
   if meta then
      setmetatable(copy,meta)
   end
	for key, value in pairs(original) do
		if type(value) == "table" then
			value = utils.deepCopy(value)
		end
      
      if type(value):find("Vector") then
			value = value:copy()
		end
		copy[key] = value
	end
	return copy
end

---Splits a string into instructions on how to split this.  
---{word:string,len:number} = word  
---number = whitespace  
---boolean = line break  
---@param text string
function utils.string2instructions(text)
   local instructions = {}
   for line in text:gmatch('[^\n]+') do
      for word,white in line:gmatch("([^%s]+)(%s*)") do
         if #word > 0 then
            table.insert(instructions,{word=word,len=client.getTextWidth(word)})
         end
         table.insert(instructions,client.getTextWidth(white))
      end
      if type(instructions[#instructions]) == "number" then -- remove excess whitespace
         instructions[#instructions] = nil
      end
      table.insert(instructions,true)
   end

   -- remove excess data
   for _ = 1, 2, 1 do -- trim excess line breaks and whitespaces
      local last_type = type(instructions[#instructions])
      if last_type == "boolean" or last_type == "number" then
         instructions[#instructions] = nil
      end
   end
   return instructions
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
---@field RenderType ModelPart.renderType
---@field BorderThickness Vector4
---@field BORDER_THICKNESS_CHANGED EventLib
---@field ExcludeMiddle boolean
---@field Visible boolean
---@field id integer
local sprite = {}
sprite.__index = sprite

local sprite_next_free = 0
---@return Sprite
function sprite.new(obj)
   local new = obj or {}
   setmetatable(new,sprite)
   new.Texture = new.Texture or debug.texture
   new.TEXTURE_CHANGED = eventLib.new()
   new.MODELPART_CHANGED = eventLib.new()
   new.Position = new.Position or vectors.vec3()
   new.UV = new.UV or vectors.vec4(0,0,1,1)
   new.Size = new.Size or vectors.vec2(16,16)
   new.Color = new.Color or vectors.vec3(1,1,1)
   new.Scale = new.Scale or 4
   new.DIMENSIONS_CHANGED = eventLib.new()
   new.RenderTasks = new.RenderTasks or {}
   new.RenderType = new.RenderType or "EMISSIVE_SOLID"
   new.BorderThickness = new.BorderThickness or vectors.vec4(0,0,0,0)
   new.BORDER_THICKNESS_CHANGED = eventLib.new()
   new.ExcludeMiddle = new.ExcludeMiddle or false
   new.Cursor = vectors.vec2()
   new.CURSOR_CHANGED = eventLib.new()
   new.Visible = true
   new.id = new.id or sprite_next_free
   sprite_next_free = sprite_next_free + 1
   
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
function sprite:setModelpart(part)
   self.Modelpart = part
   self.MODELPART_CHANGED:invoke(self.Modelpart)
   return self
end


---Sets the displayed image texture on the sprite.
---@param texture Texture
---@return Sprite
function sprite:setTexture(texture)
   self.Texture = texture
   local dim = texture:getDimensions()
   self.UV = vectors.vec4(0,0,dim.x-1,dim.y-1)
   self.TEXTURE_CHANGED:invoke(self,self.Texture)
   return self
end

---Sets the position of the Sprite, relative to its parent.
---@param xpos number
---@param y number
---@param depth number?
---@return Sprite
function sprite:setPos(xpos,y,depth)
   self.Position = utils.figureOutVec3(xpos,y,depth or 0)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---Tints the Sprite multiplicatively
---@param rgb number|Vector3
---@param g number?
---@param b number?
---@return Sprite
function sprite:setColor(rgb,g,b)
   self.Color = utils.figureOutVec3(rgb,g,b)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---Sets the size of the sprite duh.
---@param xpos number
---@param y number
---@return Sprite
function sprite:setSize(xpos,y)
   self.Size = utils.figureOutVec2(xpos,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Position,self.Size)
   return self
end

---@param scale number
---@return Sprite
function sprite:setScale(scale)
   self.Scale = scale
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

-->====================[ Border ]====================<--

---Sets the top border thickness.
---@param units number?
---@return Sprite
function sprite:setBorderThicknessTop(units)
   self.BorderThickness.y = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the left border thickness.
---@param units number?
---@return Sprite
function sprite:setBorderThicknessLeft(units)
   self.BorderThickness.x = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the down border thickness.
---@param units number?
---@return Sprite
function sprite:setBorderThicknessDown(units)
   self.BorderThickness.z = units or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the right border thickness.
---@param units number?
---@return Sprite
function sprite:setBorderThicknessRight(units)
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
function sprite:setBorderThickness(left,top,right,bottom)
   self.BorderThickness.x = left   or 0
   self.BorderThickness.y = top    or 0
   self.BorderThickness.z = right  or 0
   self.BorderThickness.w = bottom or 0
   self.BORDER_THICKNESS_CHANGED:invoke(self,self.BorderThickness)
   return self
end

---Sets the UV region of the sprite.
---@param x number
---@param y number
---@param width number
---@param height number
---@return Sprite
function sprite:setUV(x,y,width,height)
   self.UV = vectors.vec4(x,y,width,height)
   self.BORDER_THICKNESS_CHANGED:invoke(self.BorderThickness)
   return self
end

---Sets the render type of your sprite
---@param renderType ModelPart.renderType
---@return Sprite
function sprite:setRenderType(renderType)
   self.RenderType = renderType
   self:_deleteRenderTasks()
   self:_buildRenderTasks()
   return self
end

---Set to true if you want a hole in the middle of your ninepatch
---@param toggle boolean
---@return Sprite
function sprite:excludeMiddle(toggle)
   self.ExcludeMiddle = toggle
   return self
end

function sprite:duplicate()
   local copy = {}
   for key, value in pairs(self) do
      if type(value):find("Vector") then
         value = value:copy()
      end
      copy[key] = value
   end
   return sprite.new(copy)
end

function sprite:setVisible(visibility)
   self:_updateRenderTasks()
   self.Visible = visibility
   return self
end

function sprite:_deleteRenderTasks()
   for _, task in pairs(self.RenderTasks) do
      self.Modelpart:removeTask(task:getName())
   end
   return self
end

function sprite:_buildRenderTasks()
   if not self.Modelpart then return self end
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

function sprite:_updateRenderTasks()
   if not self.Modelpart then return self end
   local dim = self.Texture:getDimensions()
   local uv = self.UV:copy():add(0,0,1,1)
   if not self.is_ninepatch then
      self.RenderTasks[1]
      :setTexture(self.Texture)
      :setPos(self.Position)
      :setScale(self.Size.x/dim.x,self.Size.y/dim.y)
      :setColor(self.Color)
      :setRenderType(self.RenderType)
      :setUVPixels(
         uv.x,
         uv.y
      ):region(
         uv.z-uv.x,
         uv.w-uv.y
      ):setVisible(self.Visible)
   else
      local sborder = self.BorderThickness*self.Scale
      local pxborder = self.BorderThickness
      local pos = self.Position
      local size = self.Size
      local uvsize = vectors.vec2(uv.z-uv.x,uv.w-uv.y)
      for _, task in pairs(self.RenderTasks) do
         task
         :setTexture(self.Texture)
         :setColor(self.Color)
         :setRenderType(self.RenderType)
      
      end
      self.RenderTasks[1]
      :setPos(
         pos
      ):setScale(
         sborder.x/dim.x,
         sborder.y/dim.y
      ):setUVPixels(
         uv.x,
         uv.y
      ):region(
         pxborder.x,
         pxborder.y
      ):setVisible(self.Visible)
      
      self.RenderTasks[2]
      :setPos(
         pos.x-sborder.x,
         pos.y,
         pos.z
      ):setScale(
         (size.x-sborder.z-sborder.x)/dim.x,
         sborder.y/dim.y
      ):setUVPixels(
         uv.x+pxborder.x,
         uv.y
      ):region(
         uvsize.x-pxborder.x-pxborder.z,
         pxborder.y
      ):setVisible(self.Visible)

      self.RenderTasks[3]
      :setPos(
         pos.x-size.x+sborder.z,
         pos.y,
         pos.z
      ):setScale(
         sborder.z/dim.x,sborder.y/dim.y
      ):setUVPixels(
         uv.z-pxborder.z,
         uv.y
      ):region(
         pxborder.z,
         pxborder.y
      ):setVisible(self.Visible)

      self.RenderTasks[4]
      :setPos(
         pos.x,
         pos.y-sborder.y,
         pos.z
      ):setScale(
         sborder.x/dim.x,
         (size.y-sborder.y-sborder.w)/dim.y
      ):setUVPixels(
         uv.x,
         uv.y+pxborder.y
      ):region(
         pxborder.x,
         uvsize.y-pxborder.y-pxborder.w
      ):setVisible(self.Visible)
      if not self.ExcludeMiddle then
         self.RenderTasks[5]
         :setPos(
            pos.x-sborder.x,
            pos.y-sborder.y,
            pos.z
         )
         :setScale(
            (size.x-sborder.x-sborder.z)/dim.x,
            (size.y-sborder.y-sborder.w)/dim.y
         ):setUVPixels(
            uv.x+pxborder.x,
            uv.y+pxborder.y
         ):region(
            uvsize.x-pxborder.x-pxborder.z,
            uvsize.y-pxborder.y-pxborder.w
         ):setVisible(self.Visible)
      else
         self.RenderTasks[5]:setVisible(false)
      end

      self.RenderTasks[6]
      :setPos(
         pos.x-size.x+sborder.z,
         pos.y-sborder.y,
         pos.z
      )
      :setScale(
         sborder.z/dim.x,
         (size.y-sborder.y-sborder.w)/dim.y
      ):setUVPixels(
         uv.z-pxborder.z,
         uv.y+pxborder.y
      ):region(
         pxborder.z,
         uvsize.y-pxborder.y-pxborder.w
      ):setVisible(self.Visible)
      
      
      self.RenderTasks[7]
      :setPos(
         pos.x,
         pos.y-size.y+sborder.w,
         pos.z
      )
      :setScale(
         sborder.x/dim.x,
         sborder.w/dim.y
      ):setUVPixels(
         uv.x,
         uv.w-pxborder.w
      ):region(
         pxborder.x,
         pxborder.w
      ):setVisible(self.Visible)

      self.RenderTasks[8]
      :setPos(
         pos.x-sborder.x,
         pos.y-size.y+sborder.w,
         pos.z
      ):setScale(
         (size.x-sborder.z-sborder.x)/dim.x,
         sborder.w/dim.y
      ):setUVPixels(
         uv.x+pxborder.x,
         uv.w-pxborder.w
      ):region(
         uvsize.x-pxborder.x-pxborder.z,
         pxborder.w
      ):setVisible(self.Visible)

      self.RenderTasks[9]
      :setPos(
         pos.x-size.x+sborder.z,
         pos.y-size.y+sborder.w,
         pos.z
      ):setScale(
         sborder.z/dim.x,
         sborder.w/dim.y
      ):setUVPixels(
         uv.z-pxborder.z,
         uv.w-pxborder.w
      ):region(
         pxborder.z,
         pxborder.w
      ):setVisible(self.Visible)
   end
end

--#endregion

--#region Element

local element_next_free = 0
---@class GNUI.element
---@field Visible boolean
---@field VISIBILITY_CHANGED EventLib
---@field Children table<any,GNUI.element|GNUI.container>
---@field ChildrenIndex integer
---@field CHILDREN_CHANGED table
---@field Parent GNUI.element|GNUI.container
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

---@class GNUI.container : GNUI.element
---@field Dimensions Vector4
---@field ContainmentRect Vector4
---@field DIMENSIONS_CHANGED EventLib
---@field Margin Vector4
---@field MARGIN_CHANGED EventLib
---@field Padding Vector4
---@field PADDING_CHANGED EventLib
---@field Anchor Vector4
---@field ANCHOR_CHANGED EventLib
---@field Sprite Sprite
---@field SPRITE_CHANGED EventLib
---@field Cursor Vector2?
---@field CURSOR_CHANGED EventLib
---@field Hovering boolean
---@field MOUSE_ENTERED EventLib
---@field MOUSE_EXITED EventLib
---@field Part ModelPart
local container = {}
container.__index = function (t,i)
   return container[i] or element[i]
end

container.__type = "GNUI.element.container"

---Creates a new container.
---@param preset GNUI.container?
function container.new(preset)
   local new = preset or element.new()
   setmetatable(new,container)
   new.Dimensions = vectors.vec4(0,0,0,0) 
   new.DIMENSIONS_CHANGED = eventLib.new()
   new.Margin = vectors.vec4()
   new.ContainmentRect = vectors.vec4() -- Dimensions but with margins and anchored applied
   new.MARGIN_CHANGED = eventLib.new()
   new.Padding = vectors.vec4()
   new.PADDING_CHANGED = eventLib.new()
   new.Anchor = vectors.vec4(0,0,0,0)
   new.ANCHOR_CHANGED = eventLib.new()
   new.Part = models:newPart("container"..new.id)
   new.PARENT_CHANGED = eventLib.new()
   models:removeChild(new.Part)
   new.Cursor = vectors.vec2() -- in local space
   new.CURSOR_CHANGED = eventLib.new()
   new.SPRITE_CHANGED = eventLib.new()
   new.Hovering = false
   new.MOUSE_ENTERED = eventLib.new()
   new.MOUSE_EXITED = eventLib.new()
   new.Sprite = nil
   
   -->==========[ Internals ]==========<--
   local debug_container 
   local debug_margin    
   local debug_padding   
   local debug_cursor
   if config.debug_visible then
      debug_container = sprite.new():setModelpart(new.Part):setTexture(textures.outline):setBorderThickness(1,1,1,1):setRenderType("EMISSIVE_SOLID"):setScale(config.debug_scale):setColor(0,1,0):excludeMiddle(true)
      debug_margin    = sprite.new():setModelpart(new.Part):setTexture(textures.outline):setBorderThickness(1,1,1,1):setRenderType("EMISSIVE_SOLID"):setScale(config.debug_scale):setColor(1,0,0):excludeMiddle(true)
      debug_padding   = sprite.new():setModelpart(new.Part):setTexture(textures.outline):setBorderThickness(1,1,1,1):setRenderType("EMISSIVE_SOLID"):setScale(config.debug_scale):excludeMiddle(true)
      debug_cursor   = sprite.new():setModelpart(new.Part):setTexture(textures.ui):setUV(6,23,6,23):setRenderType("EMISSIVE_SOLID"):setSize(1,1)
   end

   new.DIMENSIONS_CHANGED:register(function ()
      -- generate the containment rect
      new.ContainmentRect = vectors.vec4(0,0,
         (new.Dimensions.z - new.Padding.x - new.Padding.z - new.Margin.x - new.Margin.z),
         (new.Dimensions.w - new.Padding.y - new.Padding.w - new.Margin.y - new.Margin.w)
      )
      -- adjust based on parent if this has one
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
         -new.Dimensions.y-new.Margin.y-new.Padding.y,
         -config.clipping_margin
      )
      for key, value in pairs(new.Children) do
         if value.DIMENSIONS_CHANGED then
            value.DIMENSIONS_CHANGED:invoke(value.DIMENSIONS_CHANGED)
         end
      end
      if new.Sprite then
         local contain = new.ContainmentRect
         local padding = new.Padding
         new.Sprite
            :setPos(
               padding.x - contain.x,
               padding.y - contain.y,
               0)
            :setSize(
               (contain.z+padding.x+padding.z - contain.x),
               (contain.w+padding.y+padding.w - contain.y)
            )
      end
      if config.debug_visible then
         local contain = new.ContainmentRect
         local margin = new.Margin
         local padding = new.Padding

         
         debug_padding
         :setSize(
            contain.z - contain.x,
            contain.w - contain.y)
         :setPos(
            - contain.x,
            - contain.y,-config.clipping_margin * 0.8)
         
         debug_margin
         :setPos(
            margin.x + padding.x - contain.x,
            margin.y + padding.y - contain.y,
            -config.clipping_margin * 0.3)
         :setSize(
            (contain.z - contain.x + margin.z + margin.x + padding.x + padding.z),
            (contain.w - contain.y + margin.w + margin.y + padding.y + padding.w)
         )
         debug_container
         :setPos(
            padding.x - contain.x,
            padding.y - contain.y,
            -config.clipping_margin * 0.6)
         :setSize(
            (contain.z+padding.x+padding.z - contain.x),
            (contain.w+padding.y+padding.w - contain.y)
         )
      end
   end,config.internal_events_name)

   new.CURSOR_CHANGED:register(function ()
      if config.debug_visible then
         -- Display the cursor in local space
         if new.Hovering then
            debug_cursor:setPos(
               -new.Cursor.x - new.ContainmentRect.x,
               -new.Cursor.y - new.ContainmentRect.y,
               -config.clipping_margin * 0.8
            ):setVisible(true)
         else
            debug_cursor:setVisible(false)
         end
      end
   end,config.debug_event_name)

   new.MARGIN_CHANGED:register(function ()
      new.DIMENSIONS_CHANGED:invoke(new.Dimensions)
   end,config.internal_events_name)

   new.PADDING_CHANGED:register(function ()
      new.DIMENSIONS_CHANGED:invoke(new.Dimensions)
   end,config.internal_events_name)

   new.PARENT_CHANGED:register(function ()
      if new.Parent then
         new.Part:moveTo(new.Parent.Part)
      end
      new.DIMENSIONS_CHANGED:invoke(new.Dimensions)
   end)
   return new
end


---Sets the backdrop of the container.  
---note: the object dosent get applied directly, its duplicated and the clone is used instead of the original.
---@param sprite_obj Sprite
---@return GNUI.container
function container:setSprite(sprite_obj)
   if self.Sprite then
      self.Sprite:_deleteRenderTasks()
      self.Sprite = nil
   end
   self.Sprite = sprite_obj
   self.Sprite:setModelpart(self.Part)
   self.SPRITE_CHANGED:invoke()
   self.DIMENSIONS_CHANGED:invoke()
   return self
end

-->====================[ Dimensions ]====================<--

---Sets the position of the container, the size stays the same.
---@param xpos number|Vector2
---@param y number?
function container:setPos(xpos,y)
   self.Dimensions.xy = utils.figureOutVec2(xpos,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the size of the container
---@param xsize number|Vector2
---@param y number?
function container:setSize(xsize,y)
   self.Dimensions.zw = utils.figureOutVec2(xsize,y)
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the position of the top left part of the container, the bottom right stays in the same position
---@param xpos number|Vector2
---@param y number?
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
function container:setBottomRight(zpos,w)
   local old,new = self.Dimensions.xy+self.Dimensions.zw,utils.figureOutVec2(zpos,w)
   local delta = new-old
   self.Dimensions.zw = self.Dimensions.zw + delta
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the Cursor position relative to the top left of the container.
---@param xpos number|Vector2
---@param y number?
---@return GNUI.container
function container:setCursor(xpos,y)
   local new = utils.figureOutVec2(xpos,y)
   local lhovering = self.Hovering
   self.Hovering = (new.x > 0 and new.y > 0 and new.x < self.ContainmentRect.z and new.y < self.ContainmentRect.w)
   self.Cursor = new
   if self.Hovering ~= lhovering then
      if self.Hovering then
         self.MOUSE_ENTERED:invoke()
      else
         self.MOUSE_EXITED:invoke()
      end
   end
   for i, child in pairs(self.Children) do
      child:setCursor(
         self.Cursor.x-child.Dimensions.x-child.Margin.x-child.Padding.x,
         self.Cursor.y-child.Dimensions.y-child.Margin.y-child.Padding.y
      )
   end
   --self.DIMENSIONS_CHANGED:invoke(self.Dimensions)
   self.CURSOR_CHANGED:invoke(new)
   return self
end

-->====================[ Margins ]====================<--

---Sets the top margin.
---@param units number?
function container:setMarginTop(units)
   self.Margin.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left margin.
---@param units number?
function container:setMarginLeft(units)
   self.Margin.x = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down margin.
---@param units number?
function container:setMarginDown(units)
   self.Margin.z = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right margin.
---@param units number?
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
function container:setPaddingTop(units)
   self.Padding.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left padding.
---@param units number?
function container:setPaddingLeft(units)
   self.Padding.x = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down padding.
---@param units number?
function container:setPaddingDown(units)
   self.Padding.z = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right padding.
---@param units number?
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
function container:setAnchorTop(units)
   self.Anchor.y = units or 0
   self.MARGIN_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the left anchor.  
--- 0 = left part of the container is fully anchored to the left of its parent  
--- 1 = left part of the container is fully anchored to the right of its parent
---@param units number?
function container:setAnchorLeft(units)
   self.Anchor.x = units or 0
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the down anchor.  
--- 0 = bottom part of the container is fully anchored to the top of its parent  
--- 1 = bottom part of the container is fully anchored to the bottom of its parent
---@param units number?
function container:setAnchorDown(units)
   self.Anchor.z = units or 0
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the right anchor.  
--- 0 = right part of the container is fully anchored to the left of its parent  
--- 1 = right part of the container is fully anchored to the right of its parent  
---@param units number?
function container:setAnchorRight(units)
   self.Anchor.w = units or 0
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

---Sets the anchor for all sides.  
--- x 0 <-> 1 = left <-> right  
--- y 0 <-> 1 = top <-> bottom
---@param left number?
---@param top number?
---@param right number?
---@param bottom number?
function container:setAnchor(left,top,right,bottom)
   self.Anchor.x = left   or 0
   self.Anchor.y = top    or 0
   self.Anchor.z = right  or 0
   self.Anchor.w = bottom or 0
   self.DIMENSIONS_CHANGED:invoke(self,self.Dimensions)
   return self
end

--#endregion

--#region-->========================================[ Rich Text Label ]=========================================<--


---@class GNUI.Label : GNUI.container
---@field Text string
---@field Words table<any,{word:string,len:number}>
---@field RenderTasks table<any,TextTask>
---@field TEXT_CHANGED EventLib
---@field Align Vector2
---@field AutoWarp boolean
---@field FontScale number
local label = {}
label.__index = function (t,i)
   return label[i] or container[i]
end

---@return GNUI.Label
function label.new(preset)
   ---@type GNUI.Label
   local new = container.new() or preset
   new.Text = ""
   new.TEXT_CHANGED = eventLib.new()
   new.Align = vectors.vec2()
   new.Words = {}
   new.RenderTasks = {}
   new.FontScale = 1

   new.TEXT_CHANGED:register(function ()
      new
      :_bakeWords()
      :_deleteRenderTasks()
      :_buildRenderTasks()
      :_updateRenderTasks()
   end,config.internal_events_name.."_txt")

   new.DIMENSIONS_CHANGED:register(function ()
      new
      :_updateRenderTasks()
   end,config.internal_events_name.."_txt")
   setmetatable(new,label)
   return new
end

---@param text string
---@return GNUI.Label
function label:setText(text)
   self.Text = text or ""
   self.TEXT_CHANGED:invoke(self.Text)
   return self
end

---Sets how the text is anchored to the container.  
---left 0 <-> 1 right  
---up 0 <-> 1 down  
--- horizontal or vertical by default is 0
---@param horizontal number?
---@param vertical number?
---@return GNUI.Label
function label:setAlign(horizontal,vertical)
   self.Align = vectors.vec2(horizontal or 0,vertical or 0)
   self:_updateRenderTasks()
   return self
end

---Sets the font scale for all text thats by this container.
---@param scale number
function label:setFontScale(scale)
   self.FontScale = scale or 1
   self:_updateRenderTasks()
   return self
end

function label:_bakeWords()
   self.Words = utils.string2instructions(self.Text)
   return self
end

function label:_buildRenderTasks()
   for i, data in pairs(self.Words) do
      if type(data) == "table" then
         self.RenderTasks[i] = self.Part:newText("word" .. i):setText(data.word)   
      end
   end
   return self
end

function label:_updateRenderTasks()
   if #self.Words == 0 then return end
   local cursor = vectors.vec2(self.ContainmentRect.x,0)
   local current_line = 1
   local line_len = 0
   local lines = {}
   
   lines[current_line] = {width=0,len={}}
   -- generate lines
   for i, data in pairs(self.Words) do
      --- calculate where the next word should be placed
      local data_type = type(data)
      local current_word_width
      if data_type == "table" then -- word
         current_word_width = data.len * self.FontScale
         cursor.x = cursor.x + current_word_width
         line_len = line_len + current_word_width
      elseif data_type == "number" then
         current_word_width = data * self.FontScale
         cursor.x = cursor.x + current_word_width
         line_len = line_len + current_word_width
      elseif data_type == "boolean" then
         cursor.x = math.huge
      end

      -- inside bounds verification
      if cursor.x > self.ContainmentRect.z then
         -- reset cursor
         cursor.x = self.ContainmentRect.x + (current_word_width or 0)
         cursor.y = cursor.y - 8 * self.FontScale
         
         -- finalize data on next line
         lines[current_line].width = line_len * self.FontScale
         line_len = 0
         current_line = current_line + 1
         lines[current_line] = {width=0,len={}}
      end
      if data_type == "table" then
         lines[current_line].len[i] = vectors.vec2(-cursor.x + current_word_width,cursor.y) -- tells where the text should be positioned
      end
   end

   --- finalize last line
   lines[current_line].width =  line_len

   -- place render tasks
   for key, line in pairs(lines) do
      for id, word_length in pairs(line.len) do
         self.RenderTasks[id]
         :setPos(
            word_length.x + (line.width - self.ContainmentRect.z + self.ContainmentRect.x) * self.Align.x,
            word_length.y + ((current_line) * 8 * self.FontScale - (self.ContainmentRect.w - self.ContainmentRect.y)) * self.Align.y - self.ContainmentRect.y,
         -0.1)
         :setScale(self.FontScale,self.FontScale,1)
         :setVisible(true)
      end
   end
   return self
end

function label:_deleteRenderTasks()
   for key, task in pairs(self.RenderTasks) do
      self.Part:removeTask(task:getName())
   end
   return self
end


api.newContainer = container.new
api.newLabel = label.new
api.utils = utils
api.newSprite = sprite.new
return api