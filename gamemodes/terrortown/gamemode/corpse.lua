---- Corpse functions

-- namespaced because we have no ragdoll metatable
CORPSE = {}

include("corpse_shd.lua")

--- networked data abstraction layer
local dti = CORPSE.dti

function CORPSE.SetFound(rag, state)
   --rag:SetNWBool("found", state)
   rag:SetDTBool(dti.BOOL_FOUND, state)
end

function CORPSE.SetPlayerNick(rag, ply_or_name)
   -- don't have datatable strings, so use a dt entity for common case of
   -- still-connected player, and if the player is gone, fall back to nw string
   local name = ply_or_name
   if IsValid(ply_or_name) then
      name = ply_or_name:Nick()
      rag:SetDTEntity(dti.ENT_PLAYER, ply_or_name)
   end

   rag:SetNWString("nick", name)
end

function CORPSE.SetCredits(rag, credits)
   --rag:SetNWInt("credits", credits)
   rag:SetDTInt(dti.INT_CREDITS, credits)
end


--- ragdoll creation and search

-- If detective mode, announce when someone's body is found
local bodyfound = CreateConVar("ttt_announce_body_found", "1")

local function IdentifyBody(ply, rag)
   if not ply:IsTerror() then return end

   -- simplified case for those who die and get found during prep
   if GetRoundState() == ROUND_PREP then
      CORPSE.SetFound(rag, true)
      return
   end

   local finder = ply:Nick()
   local nick = CORPSE.GetPlayerNick(rag, "")
   local traitor = (rag.was_role == ROLE_TRAITOR)

   -- Announce body
   if bodyfound:GetBool() and not CORPSE.GetFound(rag, false) then
      local roletext = nil
      local role = rag.was_role
      if role == ROLE_TRAITOR then
         roletext = "body_found_t"
      elseif role == ROLE_DETECTIVE then
         roletext = "body_found_d"
      else
         roletext = "body_found_i"
      end

      LANG.Msg("body_found", {finder = finder,
                              victim = nick,
                              role = LANG.Param(roletext)})
   end

   -- Register find
   if not CORPSE.GetFound(rag, false) then
      -- will return either false or a valid ply
      local deadply = player.GetByUniqueID(rag.uqid)
      if deadply then
         deadply:SetNWBool("body_found", true)

         if traitor then
            -- update innocent's list of traitors
            SendConfirmedTraitors(GetInnocentFilter(false))
         end

         SCORE:HandleBodyFound(ply, deadply)
      end

      CORPSE.SetFound(rag, true)
   else
      -- re-set because nwvars are unreliable
      --CORPSE.SetFound(rag, true)
      --CORPSE.SetPlayerNick(rag, nick)
   end

   -- Handle kill list
   for k, vicid in pairs(rag.kills) do
      -- filter out disconnected
      local vic = player.GetByUniqueID(vicid)

      -- is this an unconfirmed dead?
      if IsValid(vic) and (not vic:GetNWBool("body_found", false)) then
         LANG.Msg("body_confirm", {finder = finder, victim = vic:Nick()})

         -- update scoreboard status
         vic:SetNWBool("body_found", true)

         -- however, do not mark body as found. This lets players find the
         -- body later and get the benefits of that
         --local vicrag = vic.server_ragdoll
         --CORPSE.SetFound(vicrag, true)
      end
   end
end

-- Covert identify concommand for traitors
local function IdentifyCommand(ply, cmd, args)
   if not IsValid(ply) then return end
   if #args != 2 then return end

   local eidx = tonumber(args[1])
   local id = tonumber(args[2])
   if (not eidx) or (not id) then return end


   if (not ply.search_id) or ply.search_id.id != id or ply.search_id.eidx != eidx then
      ply.search_id = nil
      return
   end

   ply.search_id = nil

   local rag = Entity(eidx)
   if IsValid(rag) and rag:GetPos():Distance(ply:GetPos()) < 128 then
      if not CORPSE.GetFound(rag, false) then
         IdentifyBody(ply, rag)
      end
   end
end
concommand.Add("ttt_confirm_death", IdentifyCommand)

-- Call detectives to a corpse
local function CallDetective(ply, cmd, args)
   if not IsValid(ply) then return end
   if #args != 1 then return end
   if not ply:IsActive() then return end

   local eidx = tonumber(args[1])
   if not eidx then return end

   local rag = Entity(eidx)
   if IsValid(rag) and rag:GetPos():Distance(ply:GetPos()) < 128 then
      if CORPSE.GetFound(rag, false) then
         -- show indicator to detectives
         SendUserMessage("corpse_call", GetDetectiveFilter(true), rag:GetPos())

         LANG.Msg("body_call", {player = ply:Nick(),
                                victim = CORPSE.GetPlayerNick(rag, "someone")})

      else
         LANG.Msg(ply, "body_call_error")
      end
   end
end
concommand.Add("ttt_call_detective", CallDetective)

-- Send a usermessage to client containing search results
function CORPSE.ShowSearch(ply, rag, covert, long_range)
   if not IsValid(ply) or not IsValid(rag) then return end

   if rag:IsOnFire() then
      LANG.Msg(ply, "body_burning")
      return
   end

   -- init a heap of data we'll be sending
   local nick  = CORPSE.GetPlayerNick(rag)
   local traitor = (rag.was_role == ROLE_TRAITOR)
   local role  = rag.was_role
   local eq    = rag.equipment or EQUIP_NONE
   local c4    = rag.bomb_wire or -1
   local dmg   = rag.dmgtype or DMG_GENERIC
   local wep   = rag.dmgwep or ""
   local words = rag.last_words or ""
   local hshot = rag.was_headshot or false
   local dtime = rag.time or 0

   local owner = player.GetByUniqueID(rag.uqid)
   owner = IsValid(owner) and owner:EntIndex() or -1

   -- basic sanity check
   if nick == nil or eq == nil or role == nil then return end

   if DetectiveMode() and not covert then
      IdentifyBody(ply, rag)
   end

   local credits = CORPSE.GetCredits(rag, 0)
   if ply:IsActiveSpecial() and credits > 0 and (not long_range) then
      LANG.Msg(ply, "body_credits", {num = credits})
      ply:AddCredits(credits)

      CORPSE.SetCredits(rag, 0)

      ServerLog(ply:Nick() .. " took " .. credits .. " credits from the body of " .. nick .. "\n")
      SCORE:HandleCreditFound(ply, nick, credits)
   end

   -- time of death relative to current time (saves bits)
   if dtime != 0 then
      dtime = math.Round(CurTime() - dtime)
   end

   -- identifier so we know whether a ttt_confirm_death was legit
   ply.search_id = { eidx = rag:EntIndex(), id = rag:EntIndex() + dtime }

   -- time of dna sample decay relative to current time
   local stime = 0
   if rag.killer_sample then
      stime = math.max(0, rag.killer_sample.t - CurTime())
   end

   -- build list of people this traitor killed
   local kill_entids = {}
   for k, vicid in pairs(rag.kills) do
      -- also send disconnected players as a marker
      local vic = player.GetByUniqueID(vicid)
      table.insert(kill_entids, IsValid(vic) and vic:EntIndex() or -1)
   end

   local lastid = -1
   if rag.lastid and ply:IsActiveDetective() then
      -- if the person this victim last id'd has since disconnected, send -1 to
      -- indicate this
      lastid = IsValid(rag.lastid.ent) and rag.lastid.ent:EntIndex() or -1
   end

   -- If found by detective, send to all, else just the finder
   local receiver = ply
   if ply:IsActiveDetective() then receiver = nil end

   -- Send a message with basic info
   umsg.Start("ragsrch", receiver)
   umsg.Short(rag:EntIndex()) -- 2 bytes
   umsg.Short(owner)  -- 2 bytes
   umsg.String(nick)
   umsg.Short(eq)     -- 2 bytes
   umsg.Char(role)    -- 1 byte
   umsg.Char(c4)      -- 1 byte
   umsg.Long(dmg)     -- 4 bytes, enum goes high
   umsg.String(wep)   -- 2 bytes(?)
   umsg.Bool(hshot)   -- 1 byte
   umsg.Short(dtime)  -- 2 bytes
   umsg.Short(stime)  -- 2 bytes

   umsg.Char(#kill_entids)  -- 1 byte + (2 * #kills) bytes
   for k, idx in pairs(kill_entids) do
      -- might be possible to use chars here but this is safer
      umsg.Short(idx)
   end

   umsg.Short(lastid)

   -- Who found this, so if we get this from a detective we can decide not to
   -- show a window
   umsg.Short(ply:EntIndex())

   -- Will there be a last words umsg coming up?
   umsg.Bool(words != "") -- 1b
   umsg.End()

   if words != "" then
      -- umsgs only have 128 bytes of room, so if last words is really long we
      -- have to truncate
      if string.len(words) > 127 then
         words = string.sub(words, -127)
      end

      umsg.Start("ragsrch_lw", ply)
      umsg.String(words)
      umsg.End()
   end
end


-- Returns a sample for use in dna scanner if the kill fits certain constraints,
-- else returns nil
local function GetKillerSample(victim, attacker, dmg)
   -- only guns and melee damage, not explosions
   if not (dmg:IsBulletDamage() or dmg:IsDamageType(DMG_SLASH) or dmg:IsDamageType(DMG_CLUB)) then
      return nil
   end

   if not (IsValid(victim) and IsValid(attacker) and attacker:IsPlayer()) then return end

   local dist = victim:GetPos():Distance(attacker:GetPos())

   if dist > GetConVarNumber("ttt_killer_dna_range") then return nil end

   local sample = {}
   sample.killer = attacker
   sample.killer_uid = attacker:UniqueID()
   sample.victim = victim
   sample.t      = CurTime() + (-1 * (0.019 * dist)^2 + GetConVarNumber("ttt_killer_dna_basetime"))

   return sample
end

local crimescene_keys = {"Fraction", "HitBox", "Normal", "HitPos", "StartPos"}
local poseparams = {
   "aim_yaw", "move_yaw", "aim_pitch",
--   "spine_yaw", "head_yaw", "head_pitch"
};

local function GetSceneDataFromPlayer(ply)
   local data = {
      pos      = ply:GetPos(),
      ang      = ply:GetAngles(),
      sequence = ply:GetSequence(),
      cycle    = ply:GetCycle()
   };

   for _, param in pairs(poseparams) do
      data[param] = ply:GetPoseParameter(param)
   end

   return data
end

local function GetSceneData(victim, attacker, dmginfo)
   -- only for guns for now, hull traces don't work well etc
   if not dmginfo:IsBulletDamage() then return end

   local scene = {}

   if victim.hit_trace then
      scene.hit_trace = table.CopyKeys(victim.hit_trace, crimescene_keys)
   else
      return scene
   end

   scene.victim = GetSceneDataFromPlayer(victim)

   if IsValid(attacker) and attacker:IsPlayer() then
      scene.killer = GetSceneDataFromPlayer(attacker)

      local att = attacker:LookupAttachment("anim_attachment_RH")
      local angpos = attacker:GetAttachment(att)
      if not angpos then
         scene.hit_trace.StartPos = attacker:GetShootPos()
      else
         scene.hit_trace.StartPos = angpos.Pos
      end
   end

   return scene
end

local rag_collide = CreateConVar("ttt_ragdoll_collide", "0")

-- Creates client or server ragdoll depending on settings
function CORPSE.Create(ply, attacker, dmginfo)
   if not GetConVar("ttt_server_ragdolls"):GetBool() then
      ply:CreateRagdoll()
      return nil -- signifies we should spectate GetRagdollEntity
   else
      if not IsValid(ply) then return end

      local rag = ents.Create("prop_ragdoll")
      if not IsValid(rag) then return nil end

      rag:SetPos(ply:GetPos())
      rag:SetModel(ply:GetModel())
      rag:SetAngles(ply:GetAngles())

      rag:Spawn()
      rag:Activate()

      -- nonsolid to players, but can be picked up and shot
      rag:SetCollisionGroup(rag_collide:GetBool() and COLLISION_GROUP_WEAPON or COLLISION_GROUP_DEBRIS_TRIGGER)

      -- flag this ragdoll as being a player's
      rag.player_ragdoll = true
      rag.uqid = ply:UniqueID()

      -- network data
      CORPSE.SetPlayerNick(rag, ply)
      CORPSE.SetFound(rag, false)
      CORPSE.SetCredits(rag, ply:GetCredits())

      -- if someone searches this body they can find info on the victim and the
      -- death circumstances
      rag.equipment = ply:GetEquipmentItems()
      rag.was_role = ply:GetRole()
      rag.bomb_wire = ply.bomb_wire
      rag.dmgtype = dmginfo:GetDamageType()

      local wep = util.WeaponFromDamage(dmginfo)
      rag.dmgwep = IsValid(wep) and wep:GetClass() or ""

      rag.was_headshot = (ply.was_headshot and dmginfo:IsBulletDamage())
      rag.time = CurTime()
      rag.kills = table.Copy(ply.kills)

      rag.killer_sample = GetKillerSample(ply, attacker, dmginfo)

      -- crime scene data
      rag.scene = GetSceneData(ply, attacker, dmginfo)


      -- position the bones
      local num = rag:GetPhysicsObjectCount()-1
      local v = ply:GetVelocity()

      -- bullets have a lot of force, which feels better when shooting props,
      -- but makes bodies fly, so dampen that here
      if dmginfo:IsDamageType(DMG_BULLET) or dmginfo:IsDamageType(DMG_SLASH) then
         v = v / 5
      end

      for i=0, num do
         local bone = rag:GetPhysicsObjectNum(i)
         if IsValid(bone) then
            local bp, ba = ply:GetBonePosition(rag:TranslatePhysBoneToBone(i))
            if bp and ba then
               bone:SetPos(bp)
               bone:SetAngles(ba)
            end

            -- not sure if this will work:
            bone:SetVelocity(v)
         end
      end

      -- create advanced death effects (knives)
      if ply.effect_fn then
         -- next frame, after physics is happy for this ragdoll
         local efn = ply.effect_fn
         timer.Simple(0, function() efn(rag) end)
      end

      return rag -- we'll be speccing this
   end
end
