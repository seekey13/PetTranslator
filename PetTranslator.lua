--[[
PetTranslator
Translates pet abilities to readable names for BST, SMN, and PUP.
Copyright (c) 2025 Seekey
https://github.com/seekey13/PetTranslator

This addon is designed for Ashita v4 and the CatsEyeXI private server.
]]

addon.name      = 'PetTranslator';
addon.author    = 'Seekey';
addon.version   = '0.1';
addon.desc      = 'Translates pet abilities to readable names for BST, SMN, and PUP.';
addon.link      = 'https://github.com/seekey13/PetTranslator';

require('common');

-- ============================================================================
-- Configuration
-- ============================================================================

local default_settings = T{
    -- Debug
    debug_mode = false,
};

-- ============================================================================
-- State Management
-- ============================================================================

local pettranslator = T{
    settings = default_settings,
    current_job = nil,  -- Will be 'BST', 'SMN', 'PUP', or nil
    job_level = 0,
};

-- ============================================================================
-- Pet Command Lookup Tables
-- ============================================================================

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
        pettranslator.current_job = nil
        pettranslator.job_level = 0
        return nil
    end
    
    local ok_jobs, main_job = pcall(function()
        return player:GetMainJob()
    end)
    
    if not ok_jobs then
        pettranslator.current_job = nil
        pettranslator.job_level = 0
        return nil
    end
    
    local ok_levels, main_level = pcall(function()
        return player:GetMainJobLevel()
    end)
    
    if not ok_levels then
        pettranslator.current_job = nil
        pettranslator.job_level = 0
        return nil
    end
    
    -- Job IDs: 9 = BST, 15 = SMN, 18 = PUP
    local job_name = nil
    if main_job == 9 then
        job_name = 'BST'
    elseif main_job == 15 then
        job_name = 'SMN'
    elseif main_job == 18 then
        job_name = 'PUP'
    end
    
    pettranslator.current_job = job_name
    pettranslator.job_level = job_name and main_level or 0
    
    return job_name
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

ashita.events.register('load', 'pt_load', function()
    print(chat.header(addon.name):append(chat.message('v'..addon.version..' loaded')))
    
    -- Initialize job state
    local job = update_job_state()
    if job then
        print(chat.header(addon.name):append(chat.message(string.format('Detected job: %s (Level %d)', job, pettranslator.job_level))))
    else
        print(chat.header(addon.name):append(chat.message('No pet job detected (addon dormant)')))
    end
end)

ashita.events.register('unload', 'pt_unload', function()
    print(chat.header(addon.name):append(chat.message('unloaded')))
end)

ashita.events.register('d3d_present', 'pt_loop', function()
    -- Update job state
    local job = update_job_state()
    
    -- Addon is dormant if not BST, SMN, or PUP
    if not job then
        return
    end
    
    -- TODO: Add pet translation logic here
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
            print(chat.header(addon.name):append(chat.message(string.format('Current job: %s (Level %d)', 
                pettranslator.current_job, pettranslator.job_level))))
        else
            print(chat.header(addon.name):append(chat.message('No pet job detected')))
        end
        return
    end
    
    local cmd = args[2]:lower()
    
    -- Handle pet commands: go, stop, bye
    if cmd == 'go' or cmd == 'stop' or cmd == 'bye' then
        -- Check if we have a valid pet job
        if not pettranslator.current_job then
            return
        end
        
        -- Get the job-specific ability name
        local ability_name = get_pet_command(pettranslator.current_job, cmd, pettranslator.job_level)
        
        if not ability_name then
            print(chat.header(addon.name):append(chat.error(string.format('Command "%s" not available for %s at level %d', 
                cmd, pettranslator.current_job, pettranslator.job_level))))
            return
        end
        
        -- Issue the pet command
        local pet_cmd = string.format('/pet "%s" <me>', ability_name)
        AshitaCore:GetChatManager():QueueCommand(-1, pet_cmd)
        
        if pettranslator.settings.debug_mode then
            print(chat.header(addon.name):append(chat.message(string.format('Executing: %s', pet_cmd))))
        end
        
        return
    end
    
    -- Unknown command
    print(chat.header(addon.name):append(chat.error(string.format('Unknown command: %s', cmd))))
end)
