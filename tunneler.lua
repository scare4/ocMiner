local json = require('stdlibs.json')
local robot = require('robot')
local sides = require('sides')
local component = require('component')
local term = require('term')
local computer = require('computer')

local redstone = component.redstone
local gpu = term.gpu()

local data_path = './data/miner_data.json'

local data = {
    state = '',
    mined_blocks = 0,
    moved_forwards = 0,
    moved_sides = 0,
    orientation = 0,
    expected_forwards = 150,
    expected_sideways = 10
}

local tmp_data = {
    state = '',
    mined_blocks = 0,
    moved_forwards = 0,
    moved_sides = 0,
    orientation = 0,
    expected_forwards = 0,
    expected_sideways = 0
}

function initData()
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

function writeData()
    local json_string = json.encode(data)
    local data_file = io.open(data_path, 'w')
    data_file:write(json_string)
    data_file:close()
end

function initRobot()
    data.state = 'start'
    data.mined_blocks = 0
    data.moved_forwards = 0
    data.moved_side = 0
    data.orientation = 0
    writeData()
end

function initDisplay()
    term.clear()
    gpu.setResolution(50, 16)   
    term.write('  Welcome to the miner\n')
    term.write('------------------------\n')
    term.write('do you want to load last session parametters ?(y/n)')
    local inp_str = ''
    repeat
        term.write('please use \'y\' or \'n\'')
        inp_str = term.read()
        inp_str = inp_str:sub(1,1)
    until inp_str == 'n' or inp_str == 'y'
    local ret
    if inp_str == 'n' then
        robot.select(16)
        if not robot.compareDown() then
            term.write('please put the robot on top of the block in slot 16 (bottom right corner) facing towards the excavation direction')
            os.exit()
        else
            ret = true
        end
    else
        ret = false
    end
    term.clear()
    if ret then
        term.write('Starting a new session\n')
        term.write('Please enter the length of the tunnel (positive integer)\n')
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
        term.write('Please enter the width of the tunnel (positive integer)\n')
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

function returnToCharge()
    tmp_data = data
    if data.orientation ~= 0 then
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
    while data.moved_forwards > 0 do
        robot.back()
        data.moved_forwards = data.moved_forwards - 1
    end
end

function returnToWorkPos()
    while data.moved_forwards < tmp_data.moved_forwards do
        robot.forward()
        data.moved_forwards = data.moved_forwards + 1
    end
    if tmp_data.moved_sides > 0 then
        digLeftSide()
    elseif tmp_data.moved_sides < 0 then
        digRightSide()
    end
end

function refuel()
    local energy_level = computer.energy() / computer.maxEnergy() * 100
    if energy_level < 10 then
        term.write('low power, going to charge pad')
        returnToCharge()
        for i=1,6 do
            redstone.setOutput(i, 15)
        end
        while (computer.energy() / computer.maxEnergy() * 100) < 95 do
            os.sleep(1)
        end
        for i=1,6 do
            redstone.setOutput(i, 0)
        end
        returnToWorkPos()
        return true
    end
end

function dig()
    local front, what = robot.detect()
    if not front or what == "replaceable" or what == "liquid" or what == "entity" then
        return
    else
        br = false
        while not br do
            br = robot.swing(sides.front)
        end
        robot.suck()
        data.mined_blocks = data.mined_blocks + 1
    end
end

function digUp()
    local top, what = robot.detectUp()
    if not top or what == "replaceable" or what == "liquid" then
        return
    else
        local br = true
        while br do
            br = robot.swingUp(sides.top)
        end
        robot.suck()
        data.mined_blocks = data.mined_blocks + 1
    end
end

function moveForward()
    local move = robot.forward()
    while not move do
        dig()
        move = robot.forward()
    end
end

function digLeftSide()
    robot.turnLeft()
    data.orientation = 1
    while data.moved_sides < data.expected_sideways do
        if refuel() then
            return
        end
        moveForward()
        digUp()
        data.moved_sides = data.moved_sides + 1
    end
    robot.turnLeft()
    robot.turnLeft()
    data.orientation = 3
    while data.moved_sides > 0 do
        if refuel() then
            return
        end
        moveForward()
        data.moved_sides = data.moved_sides - 1
    end
    robot.turnLeft()
    data.orientation = 0
end

function digRightSide()
    robot.turnRight()
    data.orientation = 3
    while data.moved_sides > (data.expected_sideways * -1) do
        if refuel() then
            return
        end
        moveForward()
        digUp()
        data.moved_sides = data.moved_sides - 1
    end
    robot.turnRight()
    robot.turnRight()
    data.orientation = 1
    while data.moved_sides < 0 do
        if refuel() then
            return
        end
        moveForward()
        data.moved_sides = data.moved_sides + 1
    end
    robot.turnRight()
    data.orientation = 0
end

function digNextLane()
    moveForward()
    data.moved_forwards = data.moved_forwards + 1
    digUp()
    refuel()
    digLeftSide()
    digRightSide()
end

function main(boot)
    if boot then
        initRobot()
    else
        initData()    
    end
    refuel()
    while data.moved_forwards < data.expected_forwards do
        refuel()
        moveForward()
        digUp()
        data.moved_forwards = data.moved_forwards + 1
        if data.moved_forwards % 3 == 0 then
            digLeftSide()
            digRightSide()
        end
        writeData()
    end
    returnToCharge()
    term.write('A job well done, blocks mined : '..data.mined_blocks)
end

--entry point

main(initDisplay())
