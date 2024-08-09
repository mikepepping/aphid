require_relative 'interpreter'

code = <<-CODE
  PUSH_LIT 1
  STORE_VAL one
  PUSH_LIT 2
  STORE_VAL two
  PUSH_VAL one
  PUSH_VAL two
  ADD
  PRINT
CODE

Interpreter.new.run(code)