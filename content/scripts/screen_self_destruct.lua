
function begin()
    print("begin")
    begin_load()
end

function input_event(event, action)
    if action == e_input_action.release then
        if event == e_input.back then
            update_set_screen_state_exit()
        end
    end
end

function update(screen_w, screen_h, ticks)
    local st, err = pcall(function()
        update_ui_text(1, 20, "Aegis mod enabled", 100, 2, color8(255, 255, 255, 255), 0)
        _update(screen_w, screen_h, ticks)
    end)
    if not st then
        print(err)
        update_ui_text(1, 20, string.format("%s", err), 100, 2, color8(255, 0, 0, 255), 0)
    end
end

g_fileid_printed = false
g_sent_island_locations = false
g_seen_turrets = {}
g_current_team = nil
g_id = math.random(8192)

function get_game_seconds()
    return math.floor(update_get_logic_tick() / 30)  -- 1 tick is 1/30th of a second
end

g_last_tick = 0

function is_first_friendly_carrier()
    -- clients run this script once for each carrier on this team, to avoid
    -- output congestion, we only print stuff if we are the first alive carrier on
    -- this team.
    -- this returns true if this is the first alive carrier, else false.
    local self = update_get_screen_vehicle()
    g_current_team = update_get_screen_team_id()
    if self:get() then
        local vehicle_count = update_get_map_vehicle_count()
        for i = 0, vehicle_count - 1, 1 do
            local vehicle = update_get_map_vehicle_by_index(i)
            if vehicle:get() then
                local vehicle_definition_index = vehicle:get_definition_index()
                if vehicle_definition_index == e_game_object_type.chassis_carrier then
                    if self:get_id() == vehicle:get_id() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function output_map_locations()
    -- print all the island locations, types and names and
    -- return allowed turret spawns (the gui will use these as a hint to draw the island wireframe)

    local island_count = update_get_tile_count()
    for i = 0, island_count - 1 do
        local island = update_get_tile_by_index(i)

        if island:get() then
            local island_id = island:get_id()
            local island_team = island:get_team_control()

            print(string.format("AI:%d:team=%d",
                    island_id,
                    island_team))
        end
    end

    if not g_sent_island_locations then
        g_sent_island_locations = true
        for i = 0, island_count - 1 do
            local island = update_get_tile_by_index(i)
            if island:get() then
                local island_id = island:get_id()
                local island_name = island:get_name()
                local island_type = island:get_facility_category()
                local island_position = island:get_position_xz()
                print(string.format("AI:%d:type=%d:x=%f:y=%f:name=%s",
                        island_id,
                        island_type,
                        island_position:x(),
                        island_position:y(),
                        island_name))
            end
        end
    end

    -- send turret positions and command centers
    for i = 0, island_count - 1 do
        local island = update_get_tile_by_index(i)
        if island:get() then
            local island_id = island:get_id()

            if g_seen_turrets[island_id] == nil then
                local command_center_count = island:get_command_center_count()
                for j = 0, command_center_count - 1 do
                    local command_center_pos_xz = island:get_command_center_position(j)
                    print(string.format("AIC:%d:x=%f:y=%f",
                            island_id,
                            command_center_pos_xz:x(),
                            command_center_pos_xz:y()))
                end

                local turret_spawn_count = island:get_turret_spawn_count()
                for k = 0, turret_spawn_count - 1, 1 do
                    local marker_index, is_valid = island:get_turret_spawn(k)
                    local turret_spawn_xz = island:get_marker_position(marker_index)
                    print(string.format("AIT:%d:x=%f:y=%f",
                            island_id,
                            turret_spawn_xz:x(),
                            turret_spawn_xz:y()
                    ))
                end
                if turret_spawn_count > 0 then
                    g_seen_turrets[island_id] = turret_spawn_count
                end
            end
        end
    end
end


function can_show_unit(vehicle)
    if vehicle:get() then
        -- show only:
        -- friendly things (except the drydock and space pod)
        -- hostile units that are currently visible
        if vehicle:get_attached_parent_id() == 0 then
            -- exclude docked things
            local vehicle_definition_index = vehicle:get_definition_index()
            if vehicle_definition_index ~= e_game_object_type.drydock and vehicle_definition_index ~= e_game_object_type.chassis_spaceship then
                -- not the drydock or space pod
                if g_current_team == vehicle:get_team() then
                    return true
                elseif vehicle:get_is_visible() and vehicle:get_is_observation_type_revealed() then
                    return true
                end
            end
        end
    end

    return false
end

function output_map_units()
    -- print all the visible units
    local vehicle_count = update_get_map_vehicle_count()
    for i = 0, vehicle_count - 1, 1 do
        local vehicle = update_get_map_vehicle_by_index(i)
        if can_show_unit(vehicle) then
            local vid = vehicle:get_id()
            local vteam = vehicle:get_team()
            local vehicle_definition_index = vehicle:get_definition_index()
            local position = vehicle:get_position_xz()
            print(string.format("AU:%d:def=%d:team=%d:x=%f:y=%f",
                    vid,
                    vehicle_definition_index,
                    vteam,
                    position:x(),
                    position:y()))
        end
    end
end

function _update(screen_w, screen_h, ticks)
    local now = get_game_seconds()
    if now > g_last_tick then
        g_last_tick = now
        print(string.format("T:%d", math.floor(now)))
        if is_first_friendly_carrier() then
            output_map_locations()
            output_map_units()
        end
    end
end

