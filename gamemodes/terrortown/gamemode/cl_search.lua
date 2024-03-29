-- Body search popup

local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation

local is_dmg = util.BitSet

-- "From his body you can tell XXX"
local function DmgToText(d)
   if is_dmg(d, DMG_CRUSH) then
      return T("search_dmg_crush")
   elseif is_dmg(d, DMG_BULLET) then
      return T("search_dmg_bullet")
   elseif is_dmg(d, DMG_FALL) then
      return T("search_dmg_fall")
   elseif is_dmg(d, DMG_BLAST) then
      return T("search_dmg_boom")
   elseif is_dmg(d, DMG_CLUB) then
      return T("search_dmg_club")
   elseif is_dmg(d, DMG_DROWN) then
      return T("search_dmg_drown")
   elseif is_dmg(d, DMG_SLASH) then
      return T("search_dmg_stab")
   elseif is_dmg(d, DMG_BURN) or is_dmg(d, DMG_DIRECT) then
      return T("search_dmg_burn")
   elseif is_dmg(d, DMG_SONIC) then
      return T("search_dmg_tele")
   elseif is_dmg(d, DMG_VEHICLE) then
      return T("search_dmg_car")
   else
      return T("search_dmg_other")
   end
end

-- Info type to icon mapping

-- Some icons have different appearances based on the data value. These have a
-- separate table inside the TypeToMat table.

-- Those that have a lot of possible data values are defined separately, either
-- as a function or a table.

local function DmgToMat(d)
   if is_dmg(d, DMG_BULLET) then
      return "bullet"
   elseif is_dmg(d, DMG_CRUSH) then
      return "rock"
   elseif is_dmg(d, DMG_BLAST) then
      return "splode"
   elseif is_dmg(d, DMG_FALL) then
      return "fall"
   elseif is_dmg(d, DMG_BURN) or is_dmg(d, DMG_DIRECT) then
      return "fire"
   else
      return "skull"
   end
end

local function WeaponToIcon(d)
   local wep = util.WeaponForClass(d)
   return wep and wep.Icon or "VGUI/ttt/icon_nades"
end

local TypeToMat = {
   nick="id",
   words="halp",
   eq_armor="armor",
   eq_radar="radar",
   eq_disg="disguise",
   role={[ROLE_TRAITOR]="traitor", [ROLE_DETECTIVE]="det", [ROLE_INNOCENT]="inno"},
   c4="code",
   dmg=DmgToMat,
   wep=WeaponToIcon,
   head="head",
   dtime="time",
   stime="wtester",
   lastid="lastid",
   kills="list"
};

-- Accessor for better fail handling
local function IconForInfoType(t, data)
   local base = "VGUI/ttt/icon_"
   local mat = TypeToMat[t]

   if type(mat) == "table" then
      mat = mat[data]
   elseif type(mat) == "function" then
      mat = mat(data)
   end

   if not mat then
      mat = TypeToMat["nick"]
   end

   -- ugly special casing for weapons, because they are more likely to be
   -- customized and hence need more freedom in their icon filename
   if t != "wep" then
      return base .. mat
   else
      return mat
   end
end


function PreprocSearch(raw)
   local search = {}
   for t, d in pairs(raw) do
      search[t] = {img=nil, text="", p=10}

      if t == "nick" then
         search[t].text = PT("search_nick", {player = d})
         search[t].p = 1
         search[t].nick = d
      elseif t == "role" then
         if d == ROLE_TRAITOR then
            search[t].text = T("search_role_t")
         elseif d == ROLE_DETECTIVE then
            search[t].text = T("search_role_d")
         else
            search[t].text = T("search_role_i")
         end

         search[t].p = 2
      elseif t == "words" then
         if d != "" then
            -- only append "--" if there's no ending interpunction
            local final = string.match(d, "[\\.\\!\\?]$") != nil

            search[t].text = PT("search_words", {lastwords = d .. (final and "" or "--.")})
         end
      elseif t == "eq_armor" then
         if d then
            search[t].text = T("search_armor")
            search[t].p = 17
         end
      elseif t == "eq_disg" then
         if d then
            search[t].text = T("search_disg")
            search[t].p = 18
         end
      elseif t == "eq_radar" then
         if d then
            search[t].text = T("search_radar")

            search[t].p = 19
         end
      elseif t == "c4" then
         if d > 0 then
            search[t].text= PT("search_c4", {num = d})
         end
      elseif t == "dmg" then
         search[t].text = DmgToText(d)
         search[t].p = 12
      elseif t == "wep" then
         local wep = util.WeaponForClass(d)
         local wname = wep and LANG.TryTranslation(wep.PrintName)

         if wname then
            search[t].text = PT("search_weapon", {weapon = wname})
         end
      elseif t == "head" then
         if d then
            search[t].text = T("search_head")
         end
         search[t].p = 15
      elseif t == "dtime" then
         if d != 0 then
            local ftime = string.FormattedTime(d, "%02i:%02i")
            search[t].text = PT("search_time", {time = ftime})

            search[t].text_icon = ftime

            search[t].p = 8
         end
      elseif t == "stime" then
         if d > 0 then
            local ftime = string.FormattedTime(d, "%02i:%02i")
            search[t].text = PT("search_dna", {time = ftime})

            search[t].text_icon = ftime
         end
      elseif t == "kills" then
         local num = table.Count(d)
         if num == 1 then
            local vic = Entity(d[1])
            local dc = d[1] == -1 -- disconnected
            if dc or (IsValid(vic) and vic:IsPlayer()) then
               search[t].text = PT("search_kills1", {player = (dc and "<Disconnected>" or vic:Nick())})
            end
         elseif num > 1 then
            local txt = T("search_kills2") .. "\n"

            local nicks = {}
            for k, idx in pairs(d) do
               local vic = Entity(idx)
               local dc = idx == -1
               if dc or (IsValid(vic) and vic:IsPlayer()) then
                  table.insert(nicks, (dc and "<Disconnected>" or vic:Nick()))
               end
            end

            local last = #nicks
            txt = txt .. table.concat(nicks, "\n", 1, last)
            search[t].text = txt
         end

         search[t].p = 30
      elseif t == "lastid" then
         if d and d.idx != -1 then
            local ent = Entity(d.idx)
            if IsValid(ent) and ent:IsPlayer() then
               search[t].text = PT("search_eyes", {player = ent:Nick()})

               search[t].ply = ent
            end
         end
      else
         -- Not matching a type, so don't display
         search[t] = nil
      end

      -- anything matching a type but not given a text should be removed
      if search[t] and search[t].text == "" then
         search[t] = nil
      end

      -- if there's still something here, we'll be showing it, so find an icon
      if search[t] then
         search[t].img = IconForInfoType(t, d)
      end
   end

   return search
end


-- Returns a function meant to override OnActivePanelChanged, which modifies
-- dactive and dtext based on the search information that is associated with the
-- newly selected panel
local function SearchInfoController(search, dactive, dtext)
   return function(s, pold, pnew)
             local t = pnew.info_type
             local data = search[t]
             if not data then
                ErrorNoHalt("Search: data not found", t, data)
                return
             end

             dtext:SetText(data.text)
             dactive:SetImage(data.img)
          end
end

local function ShowSearchScreen(search_raw)
   local client = LocalPlayer()
   if not IsValid(client) then return end

   local m = 8
   local bw, bh = 100, 25
   local w, h = 410, 260

   local rw, rh = (w - m*2), (h - 25 - m*2)
   local rx, ry = 0, 0

   local rows = 1
   local listw, listh = rw, (64 * rows + 6)
   local listx, listy = rx, ry

   ry = ry + listh + m*2
   rx = m

   local descw, desch = rw - m*2, 80
   local descx, descy = rx, ry

   ry = ry + desch + m

   local butx, buty = rx, ry

   local dframe = vgui.Create("DFrame")
   dframe:SetSize(w, h)
   dframe:Center()
   dframe:SetTitle(T("search_title") .. " - " .. search_raw.nick or "???")
   dframe:SetVisible(true)
   dframe:ShowCloseButton(true)
   dframe:SetMouseInputEnabled(true)
   dframe:SetKeyboardInputEnabled(true)
   dframe:SetDeleteOnClose(true)

   dframe.OnKeyCodePressed = util.BasicKeyHandler

   -- contents wrapper
   local dcont = vgui.Create("DPanel", dframe)
   dcont:SetPaintBackground(false)
   dcont:SetSize(rw, rh)
   dcont:SetPos(m, 25 + m)

   -- icon list
   local dlist = vgui.Create("DPanelSelect", dcont)
   dlist:SetPos(listx, listy)
   dlist:SetSize(listw, listh)
   dlist:EnableHorizontal(true)
   dlist:SetSpacing(1)
   dlist:SetPadding(2)

   if dlist.VBar then
      dlist.VBar:Remove()
      dlist.VBar = nil
   end

   -- description area
   local dscroll = vgui.Create("DHorizontalScroller", dlist)
   dscroll:StretchToParent(3,3,3,3)

   local ddesc = vgui.Create("ColoredBox", dcont)
   ddesc:SetColor(Color(50, 50, 50))
   ddesc:SetName(T("search_info"))
   ddesc:SetPos(descx, descy)
   ddesc:SetSize(descw, desch)

   local dactive = vgui.Create("DImage", ddesc)
   dactive:SetImage("VGUI/ttt/icon_id")
   dactive:SetPos(m, m)
   dactive:SetSize(64, 64)

   local dtext = vgui.Create("ScrollLabel", ddesc)
   dtext:SetSize(descw - 120, desch - m*2)
   dtext:MoveRightOf(dactive, m*2)
   dtext:AlignTop(m)

   local dtextlabel = dtext:GetLabel()
   dtextlabel:SetWrap(true)
   dtext:SetText("...")

   -- buttons
   local by = rh - bh - (m/2)

   local dident = vgui.Create("DButton", dcont)
   dident:SetPos(m, by)
   dident:SetSize(bw,bh)
   dident:SetText(T("search_confirm"))
   local id = search_raw.eidx + search_raw.dtime
   dident.DoClick = function() RunConsoleCommand("ttt_confirm_death", search_raw.eidx, id) end
   dident:SetDisabled(client:IsSpec() or (not client:KeyDownLast(IN_WALK)))

   local dcall = vgui.Create("DButton", dcont)
   dcall:SetPos(m*2 + bw, by)
   dcall:SetSize(bw, bh)
   dcall:SetText(T("search_call"))
   dcall.DoClick = function(s)
                      client.called_corpses = client.called_corpses or {}
                      table.insert(client.called_corpses, search_raw.eidx)
                      s:SetDisabled(true)

                      RunConsoleCommand("ttt_call_detective", search_raw.eidx)
                   end

   dcall:SetDisabled(client:IsSpec() or table.HasValue(client.called_corpses or {}, search_raw.eidx))

   local dconfirm = vgui.Create("DButton", dcont)
   dconfirm:SetPos(rw - m - bw, by)
   dconfirm:SetSize(bw, bh)
   dconfirm:SetText(T("close"))
   dconfirm.DoClick = function() dframe:Close() end


   -- Finalize search data, prune stuff that won't be shown etc
   -- search is a table of tables that have an img and text key
   local search = PreprocSearch(search_raw)

   -- Install info controller that will link up the icons to the text etc
   dlist.OnActivePanelChanged = SearchInfoController(search, dactive, dtext)

   -- Create table of SimpleIcons, each standing for a piece of search
   -- information.
   local start_icon = nil
   for t, info in SortedPairsByMemberValue(search, "p") do
      local ic = nil

      -- Certain items need a special icon conveying additional information
      if t == "nick" then
         local name = info.nick
         local avply = IsValid(search_raw.owner) and search_raw.owner or nil

         ic = vgui.Create("SimpleIconAvatar", dlist)
         ic:SetPlayer(avply)

         start_icon = ic
      elseif t == "lastid" then
         ic = vgui.Create("SimpleIconAvatar", dlist)
         ic:SetPlayer(info.ply)
         ic:SetAvatarSize(24)
      elseif info.text_icon then
         ic = vgui.Create("SimpleIconLabelled", dlist)
         ic:SetIconText(info.text_icon)
      else
         ic = vgui.Create("SimpleIcon", dlist)
      end

      ic:SetIconSize(64)
      ic:SetIcon(info.img)

      ic.info_type = t

      dlist:AddPanel(ic)
      dscroll:AddPanel(ic)
   end

   dlist:SelectPanel(start_icon)

   dframe:MakePopup()
end

local function StoreSearchResult(search)
   if search.owner then
      -- if existing result was not ours, it was detective's, and should not
      -- be overwritten
      local ply = search.owner
      if (not ply.search_result) or ply.search_result.show then

         ply.search_result = search

         -- this is useful for targetid
         local rag = Entity(search.eidx)
         if IsValid(rag) then
            rag.search_result = search
         end
      end
   end
end

local search = {}
local function ReceiveRagdollSearch(um)
   search = {}

   -- Basic info
   search.eidx = um:ReadShort()

   search.owner = Entity(um:ReadShort())
   if not (IsValid(search.owner) and search.owner:IsPlayer() and (not search.owner:Alive())) then
      search.owner = nil
   end

   search.nick = um:ReadString()

   -- Equipment
   local eq = um:ReadShort()

   -- All equipment pieces get their own icon
   search.eq_armor = util.BitSet(eq, EQUIP_ARMOR)
   search.eq_radar = util.BitSet(eq, EQUIP_RADAR)
   search.eq_disg = util.BitSet(eq, EQUIP_DISGUISE)

   -- Traitor things
   search.role = um:ReadChar()
   search.c4 = um:ReadChar()

   -- Kill info
   search.dmg = um:ReadLong()
   search.wep = um:ReadString()
   search.head = um:ReadBool()
   search.dtime = um:ReadShort()
   search.stime = um:ReadShort()

   -- Players killed
   local num_kills = um:ReadChar()
   if num_kills > 0 then
      search.kills = {}
      for i=1,num_kills do
         table.insert(search.kills, um:ReadShort())
      end
   else
      search.kills = nil
   end

   search.lastid = {idx=um:ReadShort()}

   -- should we show a menu for this result?
   search.finder = um:ReadShort()

   search.show = (LocalPlayer():EntIndex() == search.finder)

   -- continuation bit for last words
   search.has_words = um:ReadBool()

   if not search.has_words then

      if search.show then
         ShowSearchScreen(search)
      end

      StoreSearchResult(search)

      search = nil
   end

   -- if there's a last words msg coming up, don't show search yet
end
usermessage.Hook("ragsrch", ReceiveRagdollSearch)

local function ReceiveRagdollWords(um)
   -- can't do anything with this if we haven't received the first msg. I don't
   -- know if Source protects vs. receiving umsgs out of order, not dealing with
   -- that case either way
   if search and search.has_words then
      search.words = um:ReadString()

      if search.show then
         ShowSearchScreen(search)
      end

      StoreSearchResult(search)

      search = nil
   end
end
usermessage.Hook("ragsrch_lw", ReceiveRagdollWords)

