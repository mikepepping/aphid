# The code here will be bad ruby code. In fact it will be bad code in general.
# I am trying to write this so that it is as close to Aphid syntax as possible to make it easier to self write the language
# The original Aphid syntax is going to support only the absolute basics, and I mean absolute.
# If but not if-else, no && or ||, as little boolean support as possible.

# ITERATION 1
# We will only setting veriables
# Example code:
example = <<-EXAMPLE.encode('ASCII')
\\ comment
set x_pos = 1
set y_pos = 2
\0
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
OPCODE_PRINT = 8
OPCODE_HALT = 9

OPERATOR_ASSIGN = 0
OPERATORS = [
    '='.bytes,
]

ASCII_SPACE = 0x20
ASCII_BACKSLASH = 0x5c
ASCII_LOWER_A = 0x61
ASCII_UPPER_A = 0x41
ASCII_LOWER_Z = 0x7a
ASCII_UPPER_Z = 0x5a
ASCII_NULL = 0x00
ASCII_NEW_LINE = 0x0A
ASCII_UNDERSCORE = 0x5f

# Global to store out evaluated byte code i.e our program
bytecode = [] # our function stored as bytecodes


# halt? - returns true if the line is the end of execution (EOF/NULL TERMINATED STRING)
def halt?(line)
    if line[0] == ASCII_NULL
        return true
    end

    false
end

# comment? - returns true if the line is a comment
def comment?(line)
    # yes this is crazy, but our language is going to suck like this
    if line[0] == ASCII_BACKSLASH
        return true
    end

    return false
end

def read_whitespace(string, offset)
    cursor = offset
    whitespace = []
    continue = true

    while continue
        if string[cursor] == ASCII_SPACE
            whitespace << ASCII_SPACE
            cursor  = cursor + 1
        end

        if string[cursor] != ASCII_SPACE
            continue = false
        end
    end

    return whitespace
end

# read_keyword - reads what could be a valid keyword from an array of bytes and returns it as an array of bytes
def read_keyword(string, offset)
    cursor = offset
    keyword = []
    continue = true
    lower_char_range = [ASCII_LOWER_A, ASCII_LOWER_Z]

    while continue
        if string[cursor] != ASCII_SPACE
            # we are nesting to avoid implementing && and || in our first pass of the language
            if string[cursor] > lower_char_range[0] - 1
                if string[cursor] < lower_char_range[1] + 1
                    keyword << string[cursor]
                    cursor = cursor + 1
                end
            end
        end

        if string[cursor] == ASCII_SPACE
            continue = false
        end
    end

    return keyword
end

# read_name - reads a valid name from an array of bytes and returns it as an array of bytes
def read_name(string, offset)
    cursor = offset
    name = []
    continue = true
    lower_char_range = [ASCII_LOWER_A, ASCII_LOWER_Z]

    while continue
        if string[cursor] != ASCII_SPACE
            # we are nesting to avoid implementing && and || in our first pass of the language
            if string[cursor] > lower_char_range[0] - 1
                if string[cursor] < lower_char_range[1] + 1
                    name << string[cursor]
                end
            end

            # check for underscore and accept it
            if string[cursor] == ASCII_UNDERSCORE
                name << string[cursor]
            end

            cursor = cursor + 1
        end

        if string[cursor] == ASCII_SPACE
            continue = false
        end
    end

    return name
end

def read_operator(string, offset)
    cursor = offset
    possible_operator = []
    continue = true
    while continue do
        if string[cursor] == ASCII_SPACE
            continue = false
        end

        if string[cursor] == ASCII_NEW_LINE
            continue = false
        end

        if string[cursor] == ASCII_NULL
            continue = false
        end

        # ELSE
        if string[cursor] != ASCII_SPACE
            if string[cursor] != ASCII_NEW_LINE
                if string[cursor] != ASCII_NULL
                    possible_operator << string[cursor]
                    cursor = cursor + 1
                end
            end
        end
    end

    return possible_operator
end

def read_remaining(string, offset)
    cursor = offset
    continue = true
    remaining = []
    while string[cursor]
        if string[cursor] == ASCII_NULL
            return remaining
        end
        
        remaining << string[cursor]
        cursor = cursor + 1
    end
end

# str_compare - compares two null terminated arrays of characters
def str_compare(a, b)
    if len(a) != len(b)
        return false
    end

    cursor = 0
    continue = true
    len_a = len(a)
    while continue do

        if a[cursor] != b[cursor]
            return false
        end

        cursor = cursor + 1
        if(cursor > len_a)
            continue = false
        end
    end

    return true
end

def len(array)
    array.size
end

# var_dec? - returns true (0) if the line is a variable declaration
def var_dec?(line)
    # ignore leading whitespace
    cursor = 0
    continue = true
    while continue do
        if line[cursor] != ASCII_SPACE
            continue = false
        end

        if line[cursor] == ASCII_SPACE
            cursor = cursor + 1
        end
    end

    set_keyword = read_keyword(line, cursor)
    
    if str_compare(set_keyword, 'set'.bytes) == false
        return false
    end

    true
end

def eval_var_dec(line, bytecode)
    # ignore leading whitespace
    cursor = 0
    continue = true
    ignore = read_whitespace(line, cursor)
    cursor = cursor + len(ignore)


    # check for "set"
    set_keyword = read_keyword(line, cursor)
    if str_compare(set_keyword, 'set'.bytes) == false
        fail "Expected 'set', found #{set_keyword}"
    end
    cursor = cursor + len(set_keyword)


    # check for a space before the name
    whitespace = read_whitespace(line, cursor)
    if len(whitespace) == 0
        fail "Missing whitespace"
    end
    cursor = cursor + len(whitespace)

    # now we need to check that there is a name and then a space
    # so we will run along until we find a space storing each character, if a character that isnt a-z or _ we will return false (1)

    name = read_name(line, cursor)

    # a name must be at least one character
    if len(name) < 1
        fail "Name not long enough"
    end
    cursor = cursor + len(name)
    debugger

    whitespace = read_whitespace(line, cursor)
    if len(whitespace) == 0
        fail "Missing whitespace"
    end
    cursor = cursor + len(whitespace)

    operator = read_operator(line, cursor)
    if operator?(operator) == false
        fail "Expecting operator, got #{operator}"
    end
    cursor = cursor + len(operator)

    whitespace = read_whitespace(line, cursor)
    if len(whitespace) == 0
        fail "Expected whitespace, got #{whitespage}"
    end
    cursor = cursor + len(whitespace)

    # we will assume everything between the cursor and the end of the line will the value
    value = read_remaining(line, cursor)

    code = [OPCODE_STORE_NAME, name, value]
    bytecode << code
end

def operator?(string)
    continue = true
    i = 0
    operator_len = len(OPERATORS)
    while continue
        same = str_compare(string, OPERATORS[i])
        if same == true
            return true
        end

        i = i + 1
        if operator_len < i
            continue = false
        end 
    end

    return false
end

# eval_line
# line array[byte] - an array of bytes representing a line, should be null terminated, ascii only, should not contain return characters
def lex_line(line, bytecode)
    if comment?(line)
        return true
    end

    if halt?(line)
        bytecode << [OPCODE_HALT]
        return true
    end

    if var_dec?(line)
        return eval_var_dec(line, bytecode)
    end

    return false
end


def lex_lines(lines, bytecode)
    reading_lines = true
    cursor = 0
    line_index = 0
    while reading_lines do
        line = []
        reading_single_line = true
        while reading_single_line do
            if lines[cursor] == ASCII_NEW_LINE
                reading_single_line = false
                line << ASCII_NULL
            end

            if lines[cursor] == ASCII_NULL
                reading_single_line = false
                reading_lines = false
                line << lines[cursor]
            end

            if lines[cursor] != ASCII_NEW_LINE
                if lines[cursor] != ASCII_NULL
                    line << lines[cursor]
                end
            end

            cursor = cursor + 1
        end

        line_index = line_index + 1
        parsed = lex_line(line, bytecode)

        ## ASSERT FOR DEV ONLY
        if parsed == false
            fail "Failed to parse line #{line_index}: #{line.pack('c*')}"
        end
        
        puts "Line [#{line_index}]: #{line}"
    end

end

def save_bytecode(bytecode)
    puts __method__.to_s
    open('byte.code', 'w') do |file|
        bytecode.each do |code|
            file.puts code
        end
    end
end


lex_lines(example, bytecode)
puts "bytecode: #{bytecode}"
save_bytecode(bytecode)