local json = require('libs.json') --libraries
local robot = require('robot')
local sides = require('sides')
local component = require('component')
local term = require('term')
local computer = require('computer')

local redstone = component.redstone --sub libraries
local gpu = component.gpu

local data_path = './data/miner_data.json' --path to save file

local data = { --main program data
    state = '',
    mined_blocks = 0,
    moved_forwards = 0,
    moved_sides = 0,
    orientation = 0,
    expected_forwards = 150,
    expected_sideways = 10
}

local tmp_data = { --temporary data used to store data when returning to charge pad
    state = '',
    mined_blocks = 0,
    moved_forwards = 0,
    moved_sides = 0,
    orientation = 0,
    expected_forwards = 0,
    expected_sideways = 0
}

function initData() --loads saved data
    local data_file = io.open(data_path, 'r')
    local json_string = data_file:read('*all')
    local json_data = json.decode(json_string)
    data.state = json_data.state
    data.mined_blocks = json_data.mined_blocks
    data.moved_forwards = json_data.moved_forwards
    data.moved_side = json_data.moved_side
    data.orientation = json_data.orientation
    data.expected_forwards = json_data.expected_forwards
    data.expected_sideways = json_data.expected_sideways
end

function writeData() --writes current robot data the the file
    local json_string = json.encode(data)
    local data_file = io.open(data_path, 'w')
    data_file:write(json_string)
    data_file:close()
end

function initRobot() --resets the robot data
    data.state = 'start'
    data.mined_blocks = 0
    data.moved_forwards = 0
    data.moved_side = 0
    data.orientation = 0
    writeData()
end

function initDisplay() --welcomes the user and asks for the wanted parameters
    term.clear()
    gpu.setResolution(50, 16)   
    term.write('  Welcome to the miner\n') --greetings
    term.write('------------------------\n')
    term.write('do you want to load last session parametters ?(y/n)')
    local inp_str = ''
    repeat --validity check for (y/n) input
        term.write('please use \'y\' or \'n\'')
        inp_str = term.read()
        inp_str = inp_str:sub(1,1)
    until inp_str == 'n' or inp_str == 'y'
    local ret
    if inp_str == 'n' then
        ret = true
    else
        ret = false
    end
    term.clear()
    if ret then
        term.write('Starting a new session\n') --aquirring new parameters
        term.write('Please enter the length of the tunnel (positive integer)\n') --legth
        local correct_input = false
        local inp_str = ''
        repeat
            inp_str = term.read()
            local inp_num = tonumber(inp_str)
            if type(inp_num) == 'number' and inp_num % 1 == 0 then
                correct_input = true
                data.expected_forwards = inp_num
            else
                term.write('Invalid input, please enter a positive integer')
            end
        until (correct_input)
        term.write('Please enter the width of the tunnel (positive integer)\n') --width
        correct_input = false
        inp_str = ''
        repeat
            inp_str = term.read()
            local inp_num = tonumber(inp_str)
            if type(inp_num) == 'number' and inp_num % 1 == 0 then
                correct_input = true
                data.expected_sideways = inp_num
            else
                term.write('Invalid input, please enter a positive integer')
            end
        until (correct_input)
    else
        term.write('Continuing last session\n')
    end
    return ret
end

function returnToCharge() --returns the robot to the charge pad for recharge
    tmp_data = data
    if data.orientation ~= 0 then --returns to center corridor
        if data.orientation == 3 then
            while data.moved_sides < 0 do
                robot.back()
                data.moved_sides = data.moved_sides + 1
            end
            while data.moved_sides > 0 do
                robot.forward()
                data.moved_sides = data.moved_sides - 1
            end
            robot.turnLeft()
            data.orientation = 0
        else
            while data.moved_sides < 0 do
                robot.forward()
                data.moved_sides = data.moved_sides + 1
            end
            while data.moved_sides > 0 do
                robot.back()
                data.moved_sides = data.moved_sides - 1
            end
            robot.turnRight()
            data.orientation = 0
        end
    end
    while data.moved_forwards > 0 do --return to charge pad
        robot.back()
        data.moved_forwards = data.moved_forwards - 1
    end
end

function returnToWorkPos() --returns the robot from the charge pad to its current work position after recharge
    while data.moved_forwards < tmp_data.moved_forwards do --goes back to corridor
        robot.forward()
        data.moved_forwards = data.moved_forwards + 1
    end
    if tmp_data.moved_sides > 0 then --resume activity
        digLeftSide()
    elseif tmp_data.moved_sides < 0 then
        digRightSide()
    end
end

function recharge()
    for i=1,6 do --output redstone to activate the charger
        redstone.setOutput(i, 15)
    end
    while (computer.energy() / computer.maxEnergy() * 100) < 95 do --wait until charge
        os.sleep(1)
    end
    for i=1,6 do --stops outputing redstone
        redstone.setOutput(i, 0)
    end
end

function refuel() --if power is low, returns the robot to the charge pad, wait until full charge, returns to the actual working pos and return true, false if charge is not needed
    local energy_level = computer.energy() / computer.maxEnergy() * 100 --checks for power level
    if energy_level < 10 then
        term.write('low power, going to charge pad')
        returnToCharge()
        recharge()
        returnToWorkPos()
        return true
    end
end

function dig() --if needed, digs the block in front of the robot
    local front, what = robot.detect()
    if not front or what == "replaceable" or what == "liquid" or what == "entity" then --if nothing blocks movement
        return
    else
        br = false
        while not br do --hit until it breaks
            br = robot.swing(sides.front)
        end
        robot.suck() --gather drop
        data.mined_blocks = data.mined_blocks + 1 --update stats
    end
end

function digUp() --if needed, digs the block on top of the robot
    local top, what = robot.detectUp()
    if not top or what == "replaceable" or what == "liquid" or what == "entity" then --if nothing to break
        return
    else
        local br = true
        while br do --hit until it breaks
            br = robot.swingUp(sides.top)
        end
        robot.suck() --gather drop
        data.mined_blocks = data.mined_blocks + 1 --update stats
    end
end

function moveForward()--moves the robot forward and if needed mines the block in front of the robot
    local move = robot.forward()
    while not move do
        dig()
        move = robot.forward()
    end
end

function digLeftSide() --digs the left side corridor
    robot.turnLeft()
    data.orientation = 1
    while data.moved_sides < data.expected_sideways do --goes to the end of the corridor
        if refuel() then
            return
        end
        if emptyInventory() then
            return
        end
        moveForward()
        digUp()
        data.moved_sides = data.moved_sides + 1
        writeData()
    end
    robot.turnLeft()
    robot.turnLeft()
    data.orientation = 3
    while data.moved_sides > 0 do --returns to center
        if refuel() then
            return
        end
        if emptyInventory() then
            return
        end
        moveForward()
        data.moved_sides = data.moved_sides - 1
        writeData()
    end
    robot.turnLeft()
    data.orientation = 0
end

function digRightSide() --digs the right side corridor
    robot.turnRight()
    data.orientation = 3
    while data.moved_sides > (data.expected_sideways * -1) do --goes to the end of the corridor
        if refuel() then
            return
        end
        if emptyInventory() then
            return
        end
        moveForward()
        digUp()
        data.moved_sides = data.moved_sides - 1
        writeData()
    end
    robot.turnRight()
    robot.turnRight()
    data.orientation = 1
    while data.moved_sides < 0 do --returns to center
        if refuel() then
            return
        end
        if emptyInventory() then
            return
        end
        moveForward()
        data.moved_sides = data.moved_sides + 1
        writeData()
    end
    robot.turnRight()
    data.orientation = 0
end

function getEmptySlots() --returns the number of empty slots in the robt's inventory
    local count = 0
    for i = 1,16 do
        robot.select(i)
        if component.inventory_controller.getStackInInternalSlot(i) == nil then
            count = count + 1
        end
    end
    return count
end

function emptyInventory() --if needed, empties the robots inventory in the chest behind the starting pos
    if getEmptySlots() > 1 then
        return false
    else
        returnToCharge()
        recharge()
        robot.turnLeft()
        robot.turnLeft()
        for i = 1,16 do
            robot.select(i)
            local item = component.inventory_controller.getStackInInternalSlot(i)
            if item.name ~= "minecraft:cobblestone" then
                robot.drop()
            else
                robot.dropDown()
            end
        end
        robot.turnLeft()
        robot.turnLeft()
        returnToWorkPos()
    end
end

function main(boot) --main program, boot is a boolean that decides if the program should reset or load saved data
    if boot then
        initRobot()
    else
        initData()
    end
    refuel()
    while data.moved_forwards < data.expected_forwards do --main loop
        refuel()
        emptyInventory()
        moveForward()
        digUp()
        data.moved_forwards = data.moved_forwards + 1
        if data.moved_forwards % 3 == 0 then --dig side corridors for 1 in 3 steps forward
            digLeftSide()
            digRightSide()
        end
        writeData()
    end
    returnToCharge() --return to starting position
    term.write('A job well done, blocks mined : '..data.mined_blocks)
end

--entry point

main(initDisplay())