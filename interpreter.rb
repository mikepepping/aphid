require 'debug'
class Interpreter
  attr_reader :values, :stack, :current_line

  def init
    @stack = []
    @values = {}
    @current_line = 0
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

  def run(bytecode)
    reset

    bytecode.each_line do |line|
      @current_line += 1
      next if blank?(line)

      code = line.strip.scan(/^[\w_]+/).first
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
        debugger
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
      else
        error!("Unknown bytecode")
      end
    end

    nil
  end

  private

  def error!(message)
    raise "#{message} at line #{@current_line}"
  end

  def reset
    @values = {}
    @current_line = 0
    @stack = []
  end

  def top
    @stack.last
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
    !!(value =~ /^[\d]+$/)
  end

  def float?(value)
    !!(value =~ /^\d+\.\d+$/)
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
