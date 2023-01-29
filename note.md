[TOC]

# DFG

## Data structure

### <a id="OpGraphVal"></a> OpGraphVal

1. Representing output resulting from an target [`OpGraphOp`](#OpGraphOp)
2. It can be used as input by multiple [`OpGraphOp`](#OpGraphOp) other than target [`OpGraphOp`](#OpGraphOp)

Key members:
| Decl                                                              | usage                                                                                  |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| <a id="OpGraphVal-input"></a> `OpGraphOp* input;`                 | pointer to the target [`OpGraphOp`](#OpGraphOp) that [output](#OpGraphOp-output) to it |
| <a id="OpGraphVal-outputs"></a> `std::vector<OpGraphOp*> output;` | pointing to [`OpGraphOp`](#OpGraphOp)s that use it as [input](#OpGraphOp-inputs)       |
   
 
### <a id="OpGraphOp"></a> OpGraphOp

1. Representing certain operation cell (e.g add operation), constant or input parameter operations
2. It can use zero or multiple [`OpGraphVal`](#OpGraphVal) as inputs and always create 1 [`OpGraphVal`](#OpGraphVal) as output

Key members:
| Decl                                                            | usage                                                                                        |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| <a id="OpGraphOp-inputs"></a> `std::vector<OpGraphVal*> input;` | pointing to [`OpGraphVal`](#OpGraphVal)s as the [input](#OpGraphVal-outputs) operand it uses |
| <a id="OpGraphOp-output"></a> `OpGraphVal* output;`             | pointing to an [`OpGraphVal`](#OpGraphVal) that it [output](#OpGraphVal-input) to            |

## Algorithm

### limitation

1. 