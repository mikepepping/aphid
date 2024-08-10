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
    COMMENT = ";"
    HALT = "HALT"
    POP = "POP"
    PUSH_LITERAL = "PUSH_LIT"
    STORE_VALUE = "STORE_VAL"
    PUSH_VAL = "PUSH_VAL"
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
  end

  module Types
    STRING = "string"
    INT = "int"
    FLOAT = "float"
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
      when Codes::POP
        error!("#{POP} called but nothing on stack") if stack.empty?

        @stack.pop
      when Codes::PUSH_LITERAL
        literal = line.split(Codes::PUSH_LITERAL).last.strip
        error!("#{Codes::PUSH_LITERAL} called with no arguments") if blank?(literal)

        type = type_of(literal)
        case type
        when Types::STRING
          literal = dequote_string(literal)
        when Types::INT
          literal = literal.to_i
        when Types::FLOAT
          literal = literal.to_f
        end

        stack.push(Value.new(literal, type))
      when Codes::PUSH_VAL
        var_name = line.split(Codes::PUSH_VAL).last.strip
        error!("#{Codes::PUSH_VAL} called with no arguments") if blank?(var_name)
        error!("#{Codes::PUSH_VAL} argument must be a symbol") unless symbol?(var_name)


        stored = @values[var_name]
        error!("#{Codes::PUSH_VAL} called but nothing stored as \"#{var_name}\"") unless stored

        stack.push(stored)
      when Codes::STORE_VALUE
        error!("#{Codes::STORE_VALUE} called but no values on stack") if @stack.empty?

        var_name = line.split(Codes::STORE_VALUE).last.strip
        error!("#{Codes::STORE_VALUE} argument must be a symbol") unless symbol?(var_name)

        stored = @values[var_name]
        if stored && stored.type != top.value
          error!("#{Codes::STORE_VALUE} type mismatch")
        end

        @values[var_name] = top
        @stack.pop
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

        first_val, second_val = @stack.pop(2)
        if first_val.type != second_val.type
          @stack.push(Value.new(0, Types::INT))
          next
        end

        @stack.push(Value.new(first_val.value == second_val.value ? 1 : 0, Types::INT))
      when Codes::GREATER_THAN
        error!("#{Codes::GREATER_THAN} called but requires at least two values on stack") if stack.size < 2

        first_val, second_val = @stack.pop(2)
        if first_val.type != second_val.type
          error!("#{Codes::GREATER_THAN} called with mixed types")
        end

        @stack.push(Value.new(first_val.value > second_val.value ? 1 : 0, Types::INT))
      when Codes::LESS_THAN
        error!("#{Codes::LESS_THAN} called but requires at least two values on stack") if stack.size < 2

        first_val, second_val = @stack.pop(2)
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

  def pop
    @stack.pop
  end

  def type_of(value)
    return Types::STRING if string?(value)
    return Types::INT if int?(value)
    return Types::FLOAT if float?(value)

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
