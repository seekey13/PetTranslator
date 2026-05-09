--[[
PetTranslator
Translates pet abilities to readable names for BST, SMN, and PUP.
Copyright (c) 2025 Seekey
https://github.com/seekey13/PetTranslator

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'PetTranslator';
addon.author    = 'Seekey';
addon.version   = '1.2';
addon.desc      = 'Translates pet abilities to readable names for BST, SMN, and PUP.';
addon.link      = 'https://github.com/seekey13/PetTranslator';

require('common');
local chat = require('chat');

-- Custom print functions for categorized output.
local function printf(fmt, ...)  print(chat.header(addon.name) .. chat.message(fmt:format(...))) end
local function warnf(fmt, ...)   print(chat.header(addon.name) .. chat.warning(fmt:format(...))) end
local function errorf(fmt, ...)  print(chat.header(addon.name) .. chat.error  (fmt:format(...))) end

-- ============================================================================
-- State Management
-- ============================================================================

local pettranslator = T{
    current_job = nil,  -- Will be 'BST', 'SMN', 'PUP', or nil
    job_level = 0,
    last_job = nil,     -- Track last known job for change detection
    autogo_enabled = false, -- Auto Go feature toggle
    autogo_last_command_time = 0, -- Cooldown tracker for Auto Go
    packet_update_pending = false, -- Prevent multiple pending job updates
};

-- ============================================================================
-- Lookup Tables
-- ============================================================================

-- Job ID to name mapping
local job_ids = T{
    [9] = 'BST',
    [15] = 'SMN',
    [18] = 'PUP',
}

-- Pet command translations by job
-- Structure: [job][command_type] = { name = "ability_name", level = min_level }
local pet_commands = T{
    BST = T{
        go = T{ name = 'Fight', level = 1 },
        stop = T{ name = 'Heel', level = 10 },
        bye = T{ name = 'Leave', level = 35 },
    },
    PUP = T{
        go = T{ name = 'Deploy', level = 1 },
        stop = T{ name = 'Retrieve', level = 10 },
        bye = T{ name = 'Deactivate', level = 1 },
    },
    SMN = T{
        go = T{ name = 'Assault', level = 1 },
        stop = T{ name = 'Retreat', level = 1 },
        bye = T{ name = 'Release', level = 1 },
    },
}

-- Get the pet command name for a given job and command type
-- Parameters:
--   job: 'BST', 'SMN', or 'PUP'
--   command_type: 'go', 'stop', or 'bye'
--   level: player's current job level
-- Returns: ability name string or nil if not available
local function get_pet_command(job, command_type, level)
    if not pet_commands[job] then
        return nil
    end
    
    local cmd = pet_commands[job][command_type]
    if not cmd then
        return nil
    end
    
    -- Check if player meets level requirement
    if level < cmd.level then
        return nil
    end
    
    return cmd.name
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Reset job state to nil/0
local function reset_job_state()
    pettranslator.current_job = nil
    pettranslator.job_level = 0
end

-- Get safe job name for display (handles nil values)
local function get_safe_job_name(job)
    return job or 'None'
end

-- Check if player has an active pet
-- Returns: boolean (true if pet is active, false otherwise)
local function has_pet()
    -- Single pcall wrapper for all checks to reduce overhead
    local ok, result = pcall(function()
        local player = GetPlayerEntity()
        if not player then
            return false
        end
        
        local pet_index = player.PetTargetIndex
        if not pet_index or pet_index == 0 then
            return false
        end
        
        local pet = GetEntity(pet_index)
        return pet ~= nil
    end)
    
    return ok and result or false
end

-- ============================================================================
-- Job State Management
-- ============================================================================

-- Update job state (check if player Main Job is BST, SMN, or PUP and get level)
-- Returns: 'BST', 'SMN', 'PUP', or nil
-- Updates: pettranslator.current_job, pettranslator.job_level
local function update_job_state()
    local ok, player = pcall(function()
        return AshitaCore:GetMemoryManager():GetPlayer()
    end)
    
    if not ok or not player then
        reset_job_state()
        return nil
    end
    
    local ok_jobs, main_job = pcall(function()
        return player:GetMainJob()
    end)
    
    if not ok_jobs then
        reset_job_state()
        return nil
    end
    
    local ok_levels, main_level = pcall(function()
        return player:GetMainJobLevel()
    end)
    
    if not ok_levels then
        reset_job_state()
        return nil
    end
    
    -- Look up job name from ID
    local job_name = job_ids[main_job]
    
    pettranslator.current_job = job_name
    pettranslator.job_level = job_name and main_level or 0
    
    return job_name
end

-- Handle job change logic
local function handle_job_change()
    local new_job = update_job_state()
    
    -- Check if job actually changed
    if new_job == pettranslator.last_job then
        return
    end
    
    -- Update tracking (silently)
    pettranslator.last_job = new_job
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

ashita.events.register('load', 'pt_load', function()
    -- Initialize job state
    local job = update_job_state()
    pettranslator.last_job = job
    
    if job then
        printf('Detected job: %s (Level %d)', job, pettranslator.job_level)
    else
        printf('No pet job detected (addon dormant)')
    end
end)

-- Listen for job change packets (0x1B, 0x44, 0x1A)
ashita.events.register('packet_in', 'pt_packet_in', function(e)
    -- 0x1B = job info, 0x44 = character update, 0x1A = party update
    if (e.id == 0x1B or e.id == 0x44 or e.id == 0x1A) then
        -- Prevent multiple pending updates
        if not pettranslator.packet_update_pending then
            pettranslator.packet_update_pending = true
            ashita.tasks.once(1, function()
                pettranslator.packet_update_pending = false
                handle_job_change()
            end)
        end
    end
end)

ashita.events.register('d3d_present', 'pt_loop', function()
    -- Early exit if addon is dormant (no pet job active)
    if not pettranslator.current_job then
        return
    end
    
    -- Auto Go Logic - only run if enabled
    if not pettranslator.autogo_enabled then
        return
    end
    
    -- Throttle Auto Go checks to every 1 second
    local current_time = os.clock()
    if current_time - pettranslator.autogo_last_command_time < 1 then
        return
    end
    
    -- Single pcall wrapper for all Auto Go checks
    local ok, should_go = pcall(function()
        local player = GetPlayerEntity()
        if not player then
            return false
        end
        
        -- Early exit: player not engaged
        if player.Status ~= 1 then
            return false
        end
        
        -- Get pet info
        local pet_index = player.PetTargetIndex
        
        -- Early exit: no pet
        if not pet_index or pet_index == 0 then
            return false
        end
        
        local pet = GetEntity(pet_index)
        if not pet then
            return false
        end
        
        -- Early exit: pet already engaged
        if pet.Status ~= 0 then
            return false
        end
        
        -- Get target info
        local target = AshitaCore:GetMemoryManager():GetTarget()
        local target_index = target:GetTargetIndex(0)
        
        -- Early exit: no valid target
        if not target_index or target_index == 0 then
            return false
        end
        
        local target_entity = GetEntity(target_index)
        if not target_entity then
            return false
        end
        
        -- Final check: target HP
        if target_entity.HPPercent <= 10 then
            return false
        end
        
        return true
    end)
    
    -- If all conditions met, issue deploy command
    if ok and should_go then
        local ability_name = get_pet_command(pettranslator.current_job, 'go', pettranslator.job_level)
        
        if ability_name then
            AshitaCore:GetChatManager():QueueCommand(1, string.format('/pet "%s" <t>', ability_name))
            pettranslator.autogo_last_command_time = current_time
        end
    end
end)

-- ============================================================================
-- Command Handler
-- ============================================================================

ashita.events.register('command', 'pt_command', function(e)
    local args = e.command:args()
    
    -- Check if command is for us
    if args[1] ~= '/pt' then
        return
    end
    
    -- Block the command from going to the game
    e.blocked = true
    
    -- No arguments - show status
    if #args == 1 then
        if pettranslator.current_job then
            printf('Current job: %s (Level %d)', pettranslator.current_job, pettranslator.job_level)
            printf('Auto Go: %s', pettranslator.autogo_enabled and 'Enabled' or 'Disabled')
        else
            warnf('No pet job detected')
        end
        return
    end
    
    local cmd = args[2]:lower()
    
    -- Handle autogo toggle
    if cmd == 'autogo' then
        pettranslator.autogo_enabled = not pettranslator.autogo_enabled
        printf('Auto Go: %s', pettranslator.autogo_enabled and 'Enabled' or 'Disabled')
        return
    end
    
    -- Handle pet commands: go, stop, bye
    if cmd == 'go' or cmd == 'stop' or cmd == 'bye' then
        -- Check if we have a valid pet job
        if not pettranslator.current_job then
            return
        end
        
        -- Get the job-specific ability name
        local ability_name = get_pet_command(pettranslator.current_job, cmd, pettranslator.job_level)
        
        if not ability_name then
            return
        end
        
        -- Check if player has an active pet
        if not has_pet() then
            warnf('No pet detected')
            return
        end
        
        -- Determine target based on command type
        local target
        if cmd == 'go' then
            -- For "go", use specified target or default to <t>
            target = args[3] or '<t>'
        else
            -- For "stop" and "bye", always use <me>
            target = '<me>'
        end
        
        -- Issue the pet command
        local pet_cmd = string.format('/pet "%s" %s', ability_name, target)
        AshitaCore:GetChatManager():QueueCommand(-1, pet_cmd)
        
        return
    end
    
    -- Unknown command
    errorf('Unknown command: %s', cmd)
end)
