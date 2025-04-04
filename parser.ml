open Types
module type Parser = sig val parse: token list -> document end
module TexParser : Parser = struct
  let rec parse_content i acc support_acc tokens =
    if i >= List.length tokens then (List.rev acc, i)
    else match List.nth tokens i with
      | Command "\\section" ->
          let (content, next_i) = parse_arg (i + 2) "section" tokens in
          parse_content next_i (Node ("section", [], default_phylo, [Leaf (content, 
default_phylo)]) :: acc) support_acc tokens
      | Command "\\tree" ->
          let (length_str, i1) = parse_arg (i + 2) "tree length" tokens in
          let (content, i2) = parse_tree_content (i1 + 1) support_acc tokens in
          let length = try Some (float_of_string length_str) with _ -> None in
          let phylo = { default_phylo with branch_length = length; support = support_acc } in
          parse_content i2 (Node ("tree", [], phylo, content) :: acc) None tokens
      | Command "\\taxon" ->
          let (name, next_i) = parse_arg (i + 2) "taxon" tokens in
          let phylo = { default_phylo with taxon = Some name; support = support_acc } in
          parse_content next_i (Leaf (name, phylo) :: acc) None tokens
      | Command "\\support" ->
          let (value, next_i) = parse_arg (i + 2) "support" tokens in
          let support = try Some (float_of_string value) with _ -> raise (ParseError "Invalid 
support value") in
          parse_content next_i acc support tokens
      | Text s -> parse_content (i + 1) (Leaf (s, default_phylo) :: acc) support_acc tokens
      | _ -> raise (ParseError (Printf.sprintf "Unexpected token at index %d" i))
  and parse_arg i context tokens =
    if i + 2 >= List.length tokens || List.nth tokens i <> LBrace || List.nth tokens (i + 2) <> 
RBrace then
      raise (ParseError (Printf.sprintf "Malformed argument for %s at index %d" context i))
    else match List.nth tokens (i + 1) with
      | Text s -> (s, i + 3)
      | _ -> raise (ParseError (Printf.sprintf "Expected text in %s argument at index %d" context 
i))
  and parse_tree_content i support_acc tokens =
    let rec aux i acc =
      if i >= List.length tokens then raise (ParseError "Unclosed tree")
      else if List.nth tokens i = RBrace then (List.rev acc, i + 1)
      else match List.nth tokens i with
        | Command "\\taxon" ->
            let (name, next_i) = parse_arg (i + 2) "taxon" tokens in
            let phylo = { default_phylo with taxon = Some name; support = support_acc } in
            aux next_i (Leaf (name, phylo) :: acc)
        | Command "\\tree" ->
            let (length_str, i1) = parse_arg (i + 2) "tree length" tokens in
            let (content, i2) = parse_tree_content (i1 + 1) support_acc tokens in
            let length = try Some (float_of_string length_str) with _ -> None in
            let phylo = { default_phylo with branch_length = length; support = support_acc } in
            aux i2 (Node ("tree", [], phylo, content) :: acc)
        | _ -> aux (i + 1) acc
    in
    aux i []
  let parse tokens =
    try
      let (children, _) = parse_content 0 [] None tokens in
      { tree = Node ("document", [], default_phylo, children); meta = [] }
    with e -> raise (ParseError (Printf.sprintf "Parsing failed: %s" (Printexc.to_string e)))
end
module NewickParser : Parser = struct
  let parse tokens =
    let input = match tokens with [Text s] -> s | _ -> raise (ParseError "Invalid Newick input") 
in
    let rec parse_subtree i =
      if i >= String.length input then raise (ParseError "Unexpected end of Newick string")
      else match input.[i] with
        | '(' ->
            let (children, i1) = parse_children (i + 1) [] in
            let (length, i2) = parse_length i1 in
            let phylo = { default_phylo with branch_length = length } in
            (Node ("tree", [], phylo, children), i2)
        | _ ->
            let (name, i1) = parse_name i in
            let (length, i2) = parse_length i1 in
            let phylo = { default_phylo with branch_length = length; taxon = Some name } in
            (Leaf (name, phylo), i2)
    and parse_children i acc =
      if i >= String.length input then raise (ParseError "Unclosed parenthesis in Newick")
      else if input.[i] = ')' then (List.rev acc, i + 1)
      else
        let (child, i1) = parse_subtree i in
        let i2 = if i1 < String.length input && input.[i1] = ',' then i1 + 1 else i1 in
        parse_children i2 (child :: acc)
    and parse_name i =
      let rec aux i acc =
        if i >= String.length input || input.[i] = ':' || input.[i] = ',' || input.[i] = ')' then
          (String.concat "" (List.rev acc), i)
        else aux (i + 1) ((String.make 1 input.[i]) :: acc)
      in
      aux i []
    and parse_length i =
      if i >= String.length input || input.[i] <> ':' then (None, i)
      else
        let rec aux i acc =
          if i >= String.length input || input.[i] = ',' || input.[i] = ')' then
            (Some (float_of_string (String.concat "" (List.rev acc))), i)
          else aux (i + 1) ((String.make 1 input.[i]) :: acc)
        in
        try aux (i + 1) [] with _ -> raise (ParseError (Printf.sprintf "Invalid length at pos %d" 
i))
    in
    try
      let (tree, _) = parse_subtree 0 in
      { tree = Node ("document", [], default_phylo, [tree]); meta = [] }
    with e -> raise (ParseError (Printf.sprintf "Newick parsing failed: %s" (Printexc.to_string 
e)))
end
