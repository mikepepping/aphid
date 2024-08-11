require 'debug'
class Interpreter
  attr_reader :values, :stack, :instruction_pointer, :lines

  def initialize(stream = nil)
    @lines = stream&.readlines || []
    @stack = []
    @values = {}
    @instruction_pointer = 0
  end

  module Codes
    DEBUG = "DBG"
    COMMENT = ";"
    HALT = "HALT"
    POP = "POP"
    PUSH = "PUSH"
    STORE = "STORE"
    ADD = "ADD"
    SUB = "SUB"
    MUL = "MUL"
    DIV = "DIV"
    PRINT = "PRINT"
    EQUAL = "EQ"
    GREATER_THAN = "GT"
    LESS_THAN = "LT"
    JUMP = "JMP"
    JUMP_TRUE = "JMP_T"
    JUMP_FALSE = "JMP_F"
    OPEN = "OPEN"
    READ = "READ"
    WRITE = "WRITE"
    CLOSE = "CLOSE"
    FRAME = "FRAME"
  end

  module Types
    STRING = "string"
    INT = "int"
    FLOAT = "float"
    SYMBOL = "symbol"
    IO = "io"
  end

  class Value
    attr_reader :value, :type
    
    def initialize(value, type)
      @value = value
      @type = type
    end

    def update(value)
      @value = value
    end

    def to_s
      "{ value: #{value}, type: #{type} }"
    end
  end

  def run
    reset

    while(true) do
      line = @lines[@instruction_pointer]
      @instruction_pointer += 1

      error!('unexpected end of program') if line == nil
      next if blank?(line)

      code = line.strip.scan(/^[\w_;]+/).first
      case code
      when Codes::COMMENT
        next
      when Codes::HALT
        return
      when Codes::DEBUG
        debugger
      when Codes::FRAME
        puts "# FRAME - #{instruction_pointer}"
        puts stack
        puts "# FRAME END"

      when Codes::POP
        error!("#{POP} called but nothing on stack") if stack.empty?

        pop
      when Codes::PUSH
        param = line.split(Codes::PUSH).last.strip
        error!("#{Codes::PUSH} called with no arguments") if blank?(param)

        type = type_of(param)
        value = case type
        when Types::STRING
          Value.new(dequote_string(param), Types::STRING)
        when Types::INT
          Value.new(param.to_i, Types::INT)
        when Types::FLOAT
          Value.new(param.to_f, Types::FLOAT)
        when Types::SYMBOL
          stored = @values[param]
          error!("#{PUSH} called with symbol but nothing stored againsted symbol '#{param}'") unless stored
          Value.new(stored.value, stored.type)
        end

        stack.push(value)
      when Codes::STORE
        error!("#{Codes::STORE} called but no values on stack") if @stack.empty?

        var_name = line.split(Codes::STORE).last.strip
        error!("#{Codes::STORE} argument must be a symbol") unless symbol?(var_name)

        stored = @values[var_name]
        if stored && stored.type != top.type
          error!("#{Codes::STORE} type mismatch")
        end

        @values[var_name] = top
        pop
      when Codes::ADD
        error!("#{Codes::ADD} called but requires at least two values on stack") if stack.size < 2

        first_param, second_param = stack.pop(2)
        error!("#{Codes::ADD} called with mismatched types") if first_param.type != second_param.type

        stack.push(Value.new(first_param.value + second_param.value, first_param.type))
      when Codes::SUB
        error!("#{Codes::SUB} called but requires at least two values on stack") if stack.size < 2

        first_param, second_param = stack.pop(2)
        error!("#{Codes::SUB} called with mismatched types") if first_param.type != second_param.type
        error!("#{Codes::SUB} called on strings") if first_param.type == Types::STRING

        stack.push(Value.new(first_param.value - second_param.value, first_param.type))
      when Codes::MUL
        error!("#{Codes::MUL} called but requires at least two values on stack") if stack.size < 2

        first_param, second_param = stack.pop(2)
        error!("#{Codes::MUL} called with mismatched types") if first_param.type != second_param.type
        error!("#{Codes::MUL} called on strings") if first_param.type == Types::STRING

        stack.push(Value.new(first_param.value * second_param.value, first_param.type))
      when Codes::DIV
        error!("#{Codes::DIV} called but requires at least two values on stack") if stack.size < 2

        first_param, second_param = stack.pop(2)
        error!("#{Codes::DIV} called with mismatched types") if first_param.type != second_param.type
        error!("#{Codes::DIV} called on strings") if first_param.type == Types::STRING

        stack.push(Value.new(first_param.value / second_param.value, first_param.type))
      when Codes::PRINT
        error!("#{Codes::PRINT} called but nothing on stack") if stack.empty?

        print top.value
      when Codes::EQUAL
        error!("#{Codes::EQUAL} called but requires at least two values on stack") if stack.size < 2

        first_val, second_val = pop(2)
        if first_val.type != second_val.type
          @stack.push(Value.new(0, Types::INT))
          next
        end

        @stack.push(Value.new(first_val.value == second_val.value ? 1 : 0, Types::INT))
      when Codes::GREATER_THAN
        error!("#{Codes::GREATER_THAN} called but requires at least two values on stack") if stack.size < 2

        first_val, second_val = pop(2)
        if first_val.type != second_val.type
          error!("#{Codes::GREATER_THAN} called with mixed types")
        end

        @stack.push(Value.new(first_val.value > second_val.value ? 1 : 0, Types::INT))
      when Codes::LESS_THAN
        error!("#{Codes::LESS_THAN} called but requires at least two values on stack") if stack.size < 2

        first_val, second_val = pop(2)
        if first_val.type != second_val.type
          error!("#{Codes::LESS_THAN} called with mixed types")
        end

        @stack.push(Value.new(first_val.value < second_val.value ? 1 : 0, Types::INT))
      
      when Codes::JUMP
        relative = line.split(Codes::JUMP).last.strip
        error!("#{Codes::JUMP} called with no arguments") if blank?(relative)
        error!("#{Codes::JUMP} called with non integer value.") unless int?(relative)

        jumps = relative.to_i
        # because the @instruction_pointer points to the next instruction, it has already been moved past this instruction
        # this means we must always offest our jumps by -1, otheriwse jumping back one will jump to this instruction
        # jumping forward by one would jump to two beyond this instruction
        @instruction_pointer += (relative.to_i - 1)
      when Codes::JUMP_FALSE
        relative = line.split(Codes::JUMP_FALSE).last.strip
        error!("#{Codes::JUMP_FALSE} called but requires at least one value on stack") if stack.size.zero?
        error!("#{Codes::JUMP_FALSE} called but stack param is not an int") unless top.type == Types::INT
        error!("#{Codes::JUMP_FALSE} called with no arguments") if blank?(relative)
        error!("#{Codes::JUMP_FALSE} called with non integer value.") unless int?(relative)

        if top.value == 0
          jumps = relative.to_i
          # because the @instruction_pointer points to the next instruction, it has already been moved past this instruction
          # this means we must always offest our jumps by -1, otheriwse jumping back one will jump to this instruction
          # jumping forward by one would jump to two beyond this instruction
          @instruction_pointer += (relative.to_i - 1)
        end
        pop
      when Codes::JUMP_TRUE
        relative = line.split(Codes::JUMP_TRUE).last.strip
        error!("#{Codes::JUMP_TRUE} called but requires at least one value on stack") if stack.size.zero?
        error!("#{Codes::JUMP_TRUE} called but stack param is not an int") unless top.type == Types::INT
        error!("#{Codes::JUMP_TRUE} called with no arguments") if blank?(relative)
        error!("#{Codes::JUMP_TRUE} called with non integer value.") unless int?(relative)

        if top.value.positive?
          jumps = relative.to_i
          # because the @instruction_pointer points to the next instruction, it has already been moved past this instruction
          # this means we must always offest our jumps by -1, otheriwse jumping back one will jump to this instruction
          # jumping forward by one would jump to two beyond this instruction
          @instruction_pointer += (relative.to_i - 1)
        end
        pop
      when Codes::OPEN
        error!("#{Codes::OPEN} called but requires at least two values on stack [path, mode]") if stack.size < 2
        path, mode = pop(2)
        
        error!("#{Codes::OPEN} called but mode is not string") unless mode.type == Types::STRING
        error!("#{Codes::OPEN} called but path is not string") unless path.type == Types::STRING

        io = open(path.value, mode.value)
        push(io, Types::IO)
        push(io.size, Types::INT)
      when Codes::READ
        # WARNING: all IO is read as bytes no matter the mode you choose
        # EXAMPLE:
        # PUSH "example.txt"
        # PUSH "r"
        # OPEN
        # STORE file_len
        # STORE open_file
        # PUSH open_file
        # PUSH file_len
        # ; now we have the IO and its length on the stack
        # READ ; this will read the whole file into the stack
        # PUSH open_file
        # CLOSE ; now the file is closed

        error!("#{Codes::READ} called but requires at least two values on stack") if stack.size < 2
        io, read_len = pop(2)

        error!("#{Codes::READ} called but io parameter is not an IO") unless io.type == Types::IO && io.value.is_a?(IO)
        error!("#{Codes::READ} called but read len paramter is not an INT") unless read_len.type == Types::INT

        read_len = read_len.value.to_i
        # When a read happens, it will push all bytes onto the stack
        # the top value will be the amount of bytes read
        # the following values are the bytes in the order where the first read byte is at the top of the stack
        # followed by all subsequent bytes in order
        read = io.value.read(read_len)
        if read.nil?
          push(0, Types::INT)
          next
        end

        bytes = read.bytes
        bytes.reverse.each do |byte|
          push(byte, Types::INT)
        end
        push(bytes.size, Types::INT)
      when Codes::WRITE
        # WARNING: all IO is written as bytes no matter the mode you choose
        # MAN: to write bytes to IO, you must push them on in the order to be written, with the first byte at the top
        #      then push the IO ontop of the stack, then push the IO and an INT 'n', where n is the number of bytes (stack items) to write.
        #      You can call WRITE and it will then WRITE the n stack items to the file.
        #      After writing the top most value with be an INT of how many bytes where written.
        # EXAMPLE - writting "hi" to an open IO stored as open_file, we push "hi\0" onto the stack so that "h" is top and "i" then "\0"
        #           are underneath. Then push the io "open_file" and and write 3 stack times to it. The top of the stack is now 3
        # PUSH 105  ; "i" 
        # PUSH 104  ; "h"
        # PUSH open_file
        # PUSH 3 ; we have 3 bytes to write
        # WRITE
        error!("#{Codes::WRITE} called but requires at least two values on stack") if stack.size < 2
        io, write_len = pop(2)
        error!("#{Codes::WRITE} called but parameter is not an IO (top of stack is not an IO)") unless io.type == Types::IO && io.value.is_a?(IO)
        error!("#{Codes::WRITE} called but write len parameted is not an INT") unless write_len.type == Types::INT


        write_len = write_len.value.to_i
        error!("#{Codes::WRITE} write count larger than stack") unless write_len >= stack.size

        bytes_written = 0
        write_len.times do
          value = pop
          error!("#{Codes::WRITE} encountered non int value") unless value.type == Types::INT

          byte = value.value
          error!("#{Codes::WRITE} attempting to write value larger than a byte") unless byte >= -128 && byte <= 255

          io.value.write([byte].pack('C*'))
          bytes_written += 1
        end

        push(bytes_written, Types::INT)
      when Codes::CLOSE
        # Closing an IO does not push anything onto the stack
        error!("#{Codes::CLOSE} called but requires at least on value on stack") if stack.empty?
        io = pop
        error!("#{Codes::CLOSE} called but parameter is not an IO (top of stack is not an IO)") unless io.type == Types::IO && io.value.is_a?(IO)

        io.value.close
      else
        error!("Unknown bytecode")
      end
    end

    nil
  end

  private

  def error!(message)
    raise "#{message} running instruction #{@instruction_pointer}"
  end

  def reset
    @values = {}
    @current_line = 0
    @stack = []
  end

  def top
    @stack.last
  end

  def push(value, type)
    @stack.push(Value.new(value, type))
  end

  def pop(n=1)
    return @stack.pop if n == 1

    @stack.pop(n)
  end

  def code_args(line, code)
    line.split(code).last.split(',').map(&:strip)
  end

  def type_of(value)
    return Types::STRING if string?(value)
    return Types::INT if int?(value)
    return Types::FLOAT if float?(value)
    return Types::SYMBOL if symbol?(value)

    error!("Unknown type of `#{value}`")
  end

  def string?(value)
    value =~ /^".*"$/
  end

  def int?(value)
    !!(value =~ /^(\-|\+){0,1}[\d]+$/)
  end

  def float?(value)
    !!(value =~ /^(\-|\+){0,1}\d+\.\d+$/)
  end

  def symbol?(value)
    !!(value =~/^[a-z_\d]+$/)
  end

  def dequote_string(string)
    error!("cannot dequote something that is not if type string") unless string?(string)

    string[1...-1]
  end

  def blank?(object)
    object.respond_to?(:empty?) ? !!object.empty? : !object
  end
end
