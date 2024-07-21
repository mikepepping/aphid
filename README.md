# Aphid

This language is just for the learning experience of writing a stackbased, bytecode backed language.

It is not intended for serious use.

## Goals
 - [ ] can store variables with static typing (once a variable is a type it cannot be re-typed)
 - [ ] can read variables
 - [ ] can evaluate arithmatic expressions
 - [ ] can evaluate boolean expressions
 - [ ] can define and execute functions
 - [ ] can define and execute while loops
 - [ ] can define and execute if statements (no if-else)
 - [ ] can define structures/types

### Stretch Goals / Quirks
 - [ ] can define interfaces (only public methods)
 - [ ] file system access
 - [ ] I want to make all types implicitly interchangable with any type that completely matches its signature (much like Go interfces, but instead for attributes) - I'm curious to know what problems this causes and solves
 - [ ] I want to make all function arguments implicity their own types, this means that if an object is passed in instead of an argument list, then if the object implements the argument list's type completely then its matching properties will be assigned to the argument list
 - [ ] Like Go, interfaces are more "duck typing" and no explicit declaration of which interface they implement needs to be stated.
