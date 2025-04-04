type metadata = (string * string) list
type phylo_data = { branch_length: float option; taxon: string option; support: float option; 
phenetic_distance: float option; timestamp: int option }
type 'a tree = Node of string * 'a * phylo_data * 'a tree list | Leaf of string * phylo_data
type document = { tree: metadata tree; meta: metadata }
type token = Command of string | LBrace | RBrace | Text of string
exception ParseError of string
let default_phylo = { branch_length = None; taxon = None; support = None; phenetic_distance = 
None; timestamp = None }
