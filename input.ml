open Types
module type InputHandler = sig val handle: string -> [ `Tex of string | `Newick of string | 
`TextList of (string * int) list ] end
module InputHandler : InputHandler = struct
  let handle input =
    if String.contains input '(' then `Newick input
    else if String.contains input '\\' then `Tex input
    else let lines = String.split_on_char '\n' input in
         let timestamped = List.mapi (fun i line -> (line, i)) lines in `TextList timestamped
end
