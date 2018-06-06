local arg = {...}

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
    expected_sideways = 25
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
    while inp_str == 'y\n' or inp_str == 'n\n' do
        term.write('please use \'y\' or \'n\'')
        inp_str = term.read()
    end
    local ret
    if inp_str == 'n\n' then
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
    if energy_level < 15 then
        term.write('low power, going to charge pad')
        returnToCharge()
        redstone.setOutput(sides.top, 15)
        while (computer.energy() / computer.maxEnergy() * 100) < 95 do
            os.sleep(1)
        end
        redstone.setOutput(sides.top, 0)
        returnToWorkPos()
        return true
    end
end

function dig()
    local front, what = robot.detect()
    if not front or what == "replaceable" or what == "liquid" then
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
    if not move then
        dig()
        robot.forward()
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
    end
    returnToCharge()
    redstone.setOutput(sides.back, 15)
    while (computer.energy() / computer.maxEnergy() * 100) < 95 do
        os.sleep(1)
    end
    redstone.setOutput(sides.back, 0)
    term.write('A job well done, blocks mined : '..data.mined_blocks)
end

--entry point

main(initDisplay())