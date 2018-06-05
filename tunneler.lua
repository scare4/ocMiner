local json = require('stdlibs.json')
local robot = require('robot')
local sides = require('sides')
local component = require('component')
local term = require('term')

local redstone = component.redstone
local gpu = term.gpu()

local data_path = './data/miner_data.json'

local data = {
    state = '',
    mined_blocks = 0,
    moved_forwards = 0,
    moved_sides = 0,
    expected_forwards = 0,
    expected_backwards = 0
}

function initData()
    local data_file = io.open(data_path, 'r')
    local json_string = data_file:read('*all')
    local json_data = json.decode(json_string)
    data.state = json_data.state
    data.mined_blocks = json_data.mined_blocks
    data.moved_forward = json_data.moved_forward
    data.moved_side = json_data.moved_side
    data.expected_forwards = json_data.expected_forwards
    data.expected_backwards = json_data.expected_backwards
end

function writeData()
    local json_string = json.encode(data)
    local data_file = io.open(data_path, 'w')
    data_file:write(json_string)
end

function initRobot()
    data.state = 'start'
    data.mined_blocks = 0
    data.moved_forward = 0
    data.moved_side = 0
    write_data()
end

function initDisplay()
    term.clear()
    gpu.setResolution(50*16)
    term.write('  Welcome to the miner')
    term.write('------------------------\n')
    term.write('do you want to load last session parametters ?(y/n)')
    local inp_str = ''
    while inp_str ~= 'y' or inp_str ~= 'n' do
        term.write('please use \'y\' or \'n\'')
    end
    local ret
    if inp_str == 'n' then
        if not robot.compareTo(16) then
            term.write('please put the robot on top of a charger facing towards the excavation direction')
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

function refuel()

end

function dig()
    local front, what = robot.detect()
    if not front or what == "replaceable" or what == "liquid" then
        return
    else
        break = false
        while not break do
            break = robot.swing(sides.front)
        end
        robot.suck()
    end
end

function digUp()

end

function moveForward()

end

function digLeftSide()

end

function digRightSide()

end

function digNextLane()

end

function main(boot)

end

--entry point

main(initDisplay())