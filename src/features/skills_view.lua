-- ChimeraVIP / Skills View
-- Czytelne umiejetnosci i staz z deltami snapshotow oraz paragonami sesyjnymi.

chimera_vip = chimera_vip or {}
chimera_overlay = chimera_overlay or chimera_vip

local C = chimera_vip
local U = C.util
C.skills_view = C.skills_view or {}
chimera_overlay.skills_view = C.skills_view
local S = C.skills_view

S.trigger_ids = S.trigger_ids or {}
S.alias_ids = S.alias_ids or {}
S.skill_capture = nil
S.skill_timer = nil
S.job_capture = nil
S.job_timer = nil
S.previous_skills = S.previous_skills or {}
S.previous_jobs = S.previous_jobs or {}
S.session_gains = S.session_gains or {}
S.capture_delay = 0.30

S.gain_aliases = {
    ["walce toporem"] = "topory",
}

local trim = U.trim
local normalize = U.normalize
local pad = U.pad_right
local colors = U.palette
local gag_line = U.gag_line

local function value_color(value, P)
    value = tonumber(value) or 0
    if value < 20 then return P.rose end
    if value < 40 then return P.peach end
    if value < 60 then return P.yellow end
    if value < 80 then return P.mint end
    return P.lavender
end

local function delta_text(delta, suffix, P)
    delta = tonumber(delta) or 0
    suffix = suffix or ""
    if delta > 0 then return P.mint .. "+" .. tostring(delta) .. suffix end
    if delta < 0 then return P.rose .. tostring(delta) .. suffix end
    return ""
end

function S:start_skills()
    if self.skill_timer then pcall(killTimer, self.skill_timer) end
    self.skill_capture = {skills={}, order={}}
    self.skill_timer = nil
end

function S:touch_skill_timer()
    if self.skill_timer then pcall(killTimer, self.skill_timer) end
    self.skill_timer = tempTimer(self.capture_delay, function()
        S.skill_timer = nil
        S:finish_skills()
    end)
end

function S:add_skill(name, level, value)
    if not self.skill_capture then return end
    name, level, value = trim(name), trim(level), tonumber(value)
    if name == "" or level == "" or not value then return end
    local key = normalize(name)
    if not self.skill_capture.skills[key] then self.skill_capture.order[#self.skill_capture.order + 1] = key end
    self.skill_capture.skills[key] = {name=name, level=level, value=value}
end

function S:parse_skill_line(line)
    if not self.skill_capture then return false end
    line = trim(line)

    local name1, level1, value1, name2, level2, value2 = line:match(
        "^(.-):%s+(%S+)%s+%[(%d+)%]%s+(.-):%s+(%S+)%s+%[(%d+)%]%s*$"
    )
    if name1 then
        self:add_skill(name1, level1, value1)
        self:add_skill(name2, level2, value2)
        return true
    end

    local name, level, value = line:match("^(.-):%s+(%S+)%s+%[(%d+)%]%s*$")
    if name then
        self:add_skill(name, level, value)
        return true
    end
    return false
end

function S:print_skill(skill, previous)
    local P = colors()
    local delta = previous and (skill.value - previous.value) or 0
    hecho(P.text .. pad(skill.name, 22)
        .. P.text_muted .. pad(skill.level, 16)
        .. value_color(skill.value, P) .. string.format("%3d", skill.value)
        .. "  " .. delta_text(delta, "", P))
end

function S:show_session_gains()
    local gains = {}
    for name, amount in pairs(self.session_gains) do gains[#gains + 1] = {name=name, amount=amount} end
    if #gains == 0 then return end
    table.sort(gains, function(a,b) return a.name < b.name end)

    local P = colors()
    hecho("\n" .. P.lavender .. "PRZYROSTY - SESJA"
        .. "\n" .. P.separator .. "-------------------------------------------------------\n\n")
    for _, gain in ipairs(gains) do
        hecho(P.text .. pad(gain.name, 30) .. P.mint .. tostring(gain.amount) .. "\n")
    end
end

function S:finish_skills()
    local capture = self.skill_capture
    if not capture then return end
    self.skill_capture = nil
    if #capture.order == 0 then return end

    local P = colors()
    hecho("\n\n" .. P.lavender .. "UMIEJETNOSCI"
        .. "\n" .. P.separator .. "-------------------------------------------------------\n\n")
    for _, key in ipairs(capture.order) do
        self:print_skill(capture.skills[key], self.previous_skills[key])
        hecho("\n")
    end
    self:show_session_gains()
    hecho("\n")

    self.previous_skills = {}
    for key, skill in pairs(capture.skills) do
        self.previous_skills[key] = {name=skill.name, level=skill.level, value=skill.value}
    end
end

function S:start_jobs()
    if self.job_timer then pcall(killTimer, self.job_timer) end
    self.job_capture = {jobs={}, order={}}
    self.job_timer = nil
end

function S:touch_job_timer()
    if self.job_timer then pcall(killTimer, self.job_timer) end
    self.job_timer = tempTimer(self.capture_delay, function()
        S.job_timer = nil
        S:finish_jobs()
    end)
end

function S:add_job(name, level, percent)
    if not self.job_capture then return end
    name, level, percent = trim(name), trim(level), tonumber(percent)
    if name == "" or level == "" or not percent then return end
    local key = normalize(name)
    if not self.job_capture.jobs[key] then self.job_capture.order[#self.job_capture.order + 1] = key end
    self.job_capture.jobs[key] = {name=name, level=level, value=percent}
end

function S:parse_job_line(line)
    if not self.job_capture then return false end
    line = trim(line)
    local name, level, percent = line:match("^(.-):%s+(.+)%s+%[(%d+)%%%]%.%s*$")
    if not name then return false end
    self:add_job(name, level, percent)
    return true
end

function S:print_job(job, previous)
    local P = colors()
    local delta = previous and (job.value - previous.value) or 0
    hecho(P.text .. pad(job.name, 20)
        .. P.text_muted .. pad(job.level, 18)
        .. value_color(job.value, P) .. string.format("%3d%%", job.value)
        .. "  " .. delta_text(delta, "%", P))
end

function S:finish_jobs()
    local capture = self.job_capture
    if not capture then return end
    self.job_capture = nil
    if #capture.order == 0 then return end

    local P = colors()
    hecho("\n\n" .. P.lavender .. "STAZ W ZAWODACH"
        .. "\n" .. P.separator .. "-------------------------------------------------------\n\n")
    for _, key in ipairs(capture.order) do
        self:print_job(capture.jobs[key], self.previous_jobs[key])
        hecho("\n")
    end
    hecho("\n")

    self.previous_jobs = {}
    for key, job in pairs(capture.jobs) do
        self.previous_jobs[key] = {name=job.name, level=job.level, value=job.value}
    end
end

function S:add_gain(raw_name)
    raw_name = normalize(raw_name)
    local display = self.gain_aliases[raw_name] or raw_name
    self.session_gains[display] = (self.session_gains[display] or 0) + 1
    local P = colors()
    hecho("\n" .. P.mint .. "[UM] Wzrost: " .. P.text .. display
        .. P.text_muted .. "  [sesja: " .. tostring(self.session_gains[display]) .. "]\n")
end

function S:install()
    U.clear_triggers(self)
    U.clear_aliases(self)

    self.alias_ids[#self.alias_ids + 1] = tempAlias([[^(?:um|umiejetnosci)$]], function()
        S:start_skills()
        send(matches[1], false)
    end)

    self.alias_ids[#self.alias_ids + 1] = tempAlias([[^staz$]], function()
        S:start_jobs()
        send("staz", false)
    end)

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*.+?:\s+.+\[\d+\].*$]],
        function()
            if not S.skill_capture then return end
            if S:parse_skill_line(getCurrentLine()) then
                gag_line()
                S:touch_skill_timer()
            end
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*Staz w zawodach:\s*$]],
        function()
            if S.job_capture then gag_line() end
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^\s*.+?:\s+.+\[\d+%\]\.\s*$]],
        function()
            if not S.job_capture then return end
            if S:parse_job_line(getCurrentLine()) then
                gag_line()
                S:touch_job_timer()
            end
        end
    )

    self.trigger_ids[#self.trigger_ids + 1] = tempRegexTrigger(
        [[^Czujesz, ze twoja bieglosc w (.+?) wzrosla\.\s*$]],
        function() S:add_gain(matches[2]) end
    )
end

S:install()
return S
