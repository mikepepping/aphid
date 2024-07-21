# The code here will be bad ruby code. In fact it will be bad code in general.
# I am trying to write this so that it is as close to Aphid syntax as possible to make it easier to self write the language
# The original Aphid syntax is going to support only the absolute basics, and I mean absolute.
# If but not if-else, no && or ||, as little boolean support as possible.

# ITERATION 1
# We will only setting veriables
# Example code:
example = <<-EXAMPLE.encode('ASCII')
\\ comment
set x = 1
set y = 2\0
EXAMPLE
example = example.bytes

# OPCODES
# A manual enum of opcodes, so we dont have to implement enums in the self written version
OPCODE_PUSH_LITERAL = 0
OPCODE_PUSH_VAR = 1
OPCODE_STORE_NAME = 2
OPCODE_LOAD_NAME = 3
OPCODE_ADD = 4
OPCODE_SUB = 5
OPCODE_DIV = 6
OPCODE_MUL = 7
OPCODE_RETURN = 8
OPCODE_PRINT = 9

# Global to store out evaluated byte code i.e our program
bytecode = [] # our function stored as bytecodes


# comment? - returns true if the line is a comment
def comment?(line)
    # yes this is crazy, but our language is going to suck like this
    if line[0] == 0x5C
        return true
    end

    return false
end

# read_name - reads a valid name from an array of bytes and returns it as an array of bytes
def read_name(string, offset)
    cursor = offset
    name = []
    continue = true
    lower_char_range = [0x61, 0x7A]
    underscore_char = 0x5f

    while continue
        if string[cursor] != space_char
            # we are nesting to avoid implementing && and || in our first pass of the language
            if string[cursor] > lower_char_range[0] - 1
                if string[cursor] < lower_char_range[1] + 1
                    name << string[cursor]
                end
            end

            # check for underscore and accept it
            if string[cursor] == 0x5f 
                name << string[cursor]
            end
        end

        if string[cursor] == space_char
            continue = false
        end

        cursor = cursor + 1
    end
end

# var_dec? - returns true (0) if the line is a variable declaration
def var_dec?(line)
    # ignore leading whitespace
    cursor = 0
    continue = true
    space_char = 0x20
    while continue do
        if line[cursor] != space_char
            continue = false
        end

        if line[cursor] == space_char
            cursor = cursor + 1
        end
    end

    # check for "set"
    s_char = 0x73
    if line[cursor] != s_char
        return false
    end
    cursor = cursor + 1

    e_char = 0x65
    if line[cursor] != e_char
        return false
    end
    cursor = cursor + 1

    t_char = 0x74
    if line[cursor] != t_char
        return false
    end
    cursor = cursor + 1
    return true
end

def eval_var_dec(line, bytecode)
    # ignore leading whitespace
    cursor = 0
    continue = true
    space_char = 0x20
    while continue do
        if line[cursor] != space_char
            continue = false
        end

        if line[cursor] == space_char
            cursor = cursor + 1
        end
    end

    # check for "set"
    s_char = 0x73
    if line[cursor] != s_char
        return false
    end
    cursor = cursor + 1

    e_char = 0x65
    if line[cursor] != e_char
        return false
    end
    cursor = cursor + 1

    t_char = 0x74
    if line[cursor] != t_char
        return false
    end
    cursor = cursor + 1
    return true

    # check for a space before the name
    if line[cursor] != space_char
        return false
    end
    cursor = cursor + 1

    # now we need to check that there is a name and then a space
    # so we will run along until we find a space storing each character, if a character that isnt a-z or _ we will return false (1)

    name = read_name(line, cursor)

    # a name must be at least one character
    if name.size < 1
        return false
    end
    cursor = cursor + name.size

    # check for a space
    if line[cursor] != space_char
        return false
    end

    # we will assume everything between the cursor and the end of the line will the value
    value = []
    continue = true
    null_term_char = 0x00
    while continue do
        if line[cursor] != null_term_char
            value << line[cursor]
            cursor = cursor + 1
        end

        if line[cursor] == null_term_char
            continue = false
        end
    end
    
    code = [OPCODE_STORE_NAME, name, value]
    puts "Adding Bytecode: #{code}"
    bytecode << code
    true 
end

# eval_line
# line array[byte] - an array of bytes representing a line, should be null terminated, ascii only, should not contain return characters
def eval_line(line, bytecode)
    if comment?(line)
        return true
    end

    if var_dec?(line)
        return eval_var_dec(line, bytecode)
    end

    return false
end


def eval_lines(lines, bytecode)
    reading_lines = true
    cursor = 0
    newline_char = 0x0A
    null_term_char = 0x00
    line_index = 0
    while reading_lines do
        line = []
        reading_single_line = true
        while reading_single_line do
            if lines[cursor] == newline_char
                reading_single_line = false
                line << null_term_char
            end

            if lines[cursor] == null_term_char
                reading_single_line = false
                reading_lines = false
            end

            if lines[cursor] != newline_char
                if lines[cursor] != null_term_char
                    line << lines[cursor]
                end
            end

            cursor = cursor + 1
        end

        line_index = line_index + 1
        parsed = eval_line(line, bytecode)
        if parsed == false
            fail "Failed to parse line #{line_index}: #{line.pack('c*')}"
        end
        puts "Line [#{line_index}]: #{line}"
    end

    puts "finished eval"
end

def save_bytecode(bytecode)
    puts "saving bytecode"
    open('byte.code', 'w') do |file|
        bytecode.each do |code|
            puts code
            file.puts code
        end
    end
end


eval_lines(example, bytecode)
puts "bytecode: #{bytecode}"
save_bytecode(bytecode)