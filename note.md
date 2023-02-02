[TOC]

# DFG

## Data structure

### OpGraphVal
<a id="OpGraphVal"></a> 

1. Representing output resulting from an target [`OpGraphOp`](#OpGraphOp)
2. It can be used as input by multiple [`OpGraphOp`](#OpGraphOp) other than target [`OpGraphOp`](#OpGraphOp)

Key members:
| Decl                                                                       | usage                                                                                          |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| <a id="OpGraphVal-input"></a> `OpGraphOp* input;`                          | pointer to the target [`OpGraphOp`](#OpGraphOp) that [output](#OpGraphOp-output) to it         |
| <a id="OpGraphVal-outputs"></a> `std::vector<OpGraphOp*> output;`          | pointing to [`OpGraphOp`](#OpGraphOp)s that use it as [input](#OpGraphOp-inputs)               |
| <a id="OpGraphVal-operand"></a>`std::vector<unsigned int> output_operand;` | Is n'th operand of the [`OpGraphOp`](#OpGraphOp) in [OpGraphVal::outputs](#OpGraphVal-outputs) |
   
 
### OpGraphOp
<a id="OpGraphOp"></a>

1. Representing certain operation cell (e.g add operation), constant or input parameter operations
2. It can use zero or multiple [`OpGraphVal`](#OpGraphVal) as inputs and always create 1 [`OpGraphVal`](#OpGraphVal) as output

Key members:
| Decl                                                            | usage                                                                                        |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| <a id="OpGraphOp-inputs"></a> `std::vector<OpGraphVal*> input;` | pointing to [`OpGraphVal`](#OpGraphVal)s as the [input](#OpGraphVal-outputs) operand it uses |
| <a id="OpGraphOp-output"></a> `OpGraphVal* output;`             | pointing to an [`OpGraphVal`](#OpGraphVal) that it [output](#OpGraphVal-input) to            |

### OpGraph
<a id="OpGraph"></a>

Container of [`OpGraphOp`](#OpGraphOp) and [`OpGraphVal`](#OpGraphVal)

Key members:
| Decl                                                            | usage                                                                                                       |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `std::vector<OpGraphOp*> op_nodes;`                             | Listing all the [`OpGraphOp`](#OpGraphOp)s                                                                  |
| `std::vector<OpGraphVal*> val_nodes;`                           | Listing all the [`OpGraphVal`](#OpGraphVal)s                                                                |
| <a id="OpGraph-inputs"></a> `std::vector<OpGraphOp*> inputs;`   | All the [`OpGraphOp`](#OpGraphOp)s used to get values outside of the loop                                   |
| <a id="OpGraph-outputs"></a> `std::vector<OpGraphOp*> outputs;` | All the [`OpGraphOp`](#OpGraphOp)s used to output values that written in the loop, but not used in the loop |

## Algorithm

### limitation
<a id="limitation"></a> 

1. Will only convert instructions inside a loop
2. Number of block contained in the loop must be 1
3. No sub loops inside the loop

In summary, the algorithm will only handle one basic block inside the loop.

### Creating DFG

1. Loop over the target block, for each instruction in the block:
   1. If is not cast instruction, create [`OpGraphVal`](#OpGraphVal) as the output of the instruction
   2. Fill in `std::map<Instruction*, OpGraphVal*> vals;` map, which is a mapping from instruction to the corresponding [`OpGraphVal`](#OpGraphVal)
   3. If is cast instruction:
      1. Find the casted instruction
      2. Find the corresponding [`OpGraphVal`](#OpGraphVal) from the map in step-1-2
      3. Fill in the map with pair of cast instruction and the [`OpGraphVal`](#OpGraphVal) found in step 1-3-2
2. Loop over the target block second time, for each instruction in the block:
   1. If is `GetElementPtr`:
      1. Transfer to $base+\sum_{i=1}^n offset_i$, where $offset_i=step\times width$ by generating add and multiplication ops
      2. Create new [`OpGraphVal`](#OpGraphVal) for instruction, replace corresponding value in map crated in step 1-2
   2. Skip `Cast`, `Br`, `Call` instruction
   3. For all other instruction:
      1. Create [`OpGraphOp`](#OpGraphOp) $op$ corresponding to instruction's opcode
      2. Find instruction's [`OpGraphVal`](#OpGraphVal) $v$ by map in step 1-2
      3. Set $op\text{->output}=v, v\text{->input}=op$
      4. For each operand $o$ used in the instruction:
         1. If operand is not instruction, then operand can only be const or input argument:
            1. Create new [`OpGraphOp`](#OpGraphOp) $op_2$ as "const"/"input"
            2. Create new [`OpGraphVal`](#OpGraphVal) $v_2$ as val of previous op
            3. Set $op_2\text{->output}=v_2, v_2\text{->input}=op_2$
            4. Add $v_2$ to $op$'s inputs, $op$ to $v_2$'s outputs
         2. Else if is instruction:
            1. If instruction inside the loop:
               1. Find instruction represent by $o$ by map in step 1-2, donate $v_3$
               2. Add $v_3$ to $op$'s inputs, $op$ to $v_3$'s outputs
            2. Else if not in the loop:
               1. Create new [`OpGraphOp`](#OpGraphOp) $op_2$ as "input"
               2. Create new [`OpGraphVal`](#OpGraphVal) $v_2$ as val of previous op
               3. Set $op_2\text{->output}=v_2, v_2\text{->input}=op_2$
               4. Add $v_2$ to $op$'s inputs, $op$ to $v_2$'s outputs
               5. Add $op_2$ to [OpGraph::inputs](#OpGraph-inputs)
      5. If instruction used outside of the target block:
         1. Create new [`OpGraphOp`](#OpGraphOp) $op_2$ as "output"
         2. Set $op_2\text{->inputs}=v, $v\text{->outputs}=op_2$
         3. Add $op_2$ to [OpGraph::outputs](#OpGraph-outputs)

### Optimize

#### remove phi node

##### Reason/Assumption
<a id="Assumption"></a>

In [limitation](#limitation) the target loop will contain only one basic block, thus phi can only be created by variables defined outside of the loop, and written in the loop.

Those variables has an initial value when first step into the loop ("const" or "input"), and take the result from in-loop instruction in the later loops

##### Step

For each phi node $\phi$ :
1. Find the only in-loop instruction operand of $phi$, donate $I$, which is an [`OpGraphVal`](#OpGraphVal)
2. Erase $\phi$ from $I\text{->output}$ and add $\phi\text{->output->output}$ into $I\text{->output}$
3. Erase all [`OpGraphOp`](#OpGraphOp) that output only to $\phi$
4. Erase all [`OpGraphVal`](#OpGraphVal) result from previous step
5. Erase $phi\text{->output}$ then erase $\phi$

##### Note

Step 3 & 4 will not erase [`OpGraphOp`](#OpGraphOp) result from in-loop instruction.

According to [Assumption](#Assumption) there is only one operand of $\phi$, donate $I$, resulting from in-loop instruction, while all others will be "input" or "const"

After step 2, $\phi$ will be removed from $I\text{->output->output}$, thus it does not only output to $\phi$

#### remove unnecessary leaf nodes

Remove [`OpGraphOp`](#OpGraphOp)s that [`OpGraphOp::output->output`](#OpGraphVal-outputs) has a size of 0.

This indicating that the result value of the [`OpGraphOp`](#OpGraphOp) has no further use for the program.

For target [`OpGraphOp`](#OpGraphOp) $op$, the removing steps:
1. Remove $op$ from all [`OpGraphVal::output`](#OpGraphVal-outputs)
2. Remove $op\text{->output}$
3. Take care of [`OpGraph::inputs`](#OpGraph-inputs) list
4. Erase $op$

## question

1. In `./llvm-passes/DFG/DFGGeneration.cpp:472~490` the base address is not added
2. One [`OpGraphVal`](#OpGraphVal) may be used twice in [`OpGraphOp`](#OpGraphOp) (e,g `add x, x`) However the [`OpGraphOp::output_operand`](#OpGraphVal-operand)" provide only one slot for each [`OpGraphOp`](#OpGraphOp).