#!/bin/bash

# Setup and Test Script for tex2html Compiler Pipeline

# Ensure OCaml and opam are installed
echo "Checking OCaml and opam installation..."
if ! command -v ocamlc &> /dev/null || ! command -v opam &> /dev/null; then
    echo "OCaml or opam not found. Please install them:"
    echo "  On macOS: brew install ocaml opam"
    echo "  Then: opam init && eval $(opam env)"
    exit 1
fi

# Initialize opam environment
eval $(opam env)

# Install ocamlbuild and ocamlfind if not present
if ! opam list | grep -q ocamlbuild; then
    echo "Installing ocamlbuild..."
    opam install ocamlbuild -y
fi
if ! opam list | grep -q ocamlfind; then
    echo "Installing ocamlfind..."
    opam install ocamlfind -y
fi

# Create project directory if not exists
mkdir -p tex2html
cd tex2html

# Create minimal versions of required files if they don’t exist
if [ ! -f "types.ml" ]; then
    cat > types.ml << 'EOF'
type metadata = (string * string) list
type phylo_data = { branch_length: float option; taxon: string option; support: float option; phenetic_distance: float option; timestamp: int option }
type 'a tree = Node of string * 'a * phylo_data * 'a tree list | Leaf of string * phylo_data
type document = { tree: metadata tree; meta: metadata }
type token = Command of string | LBrace | RBrace | Text of string
exception ParseError of string
let default_phylo = { branch_length = None; taxon = None; support = None; phenetic_distance = None; timestamp = None }
EOF
fi

if [ ! -f "input.ml" ]; then
    cat > input.ml << 'EOF'
open Types
module type InputHandler = sig val handle: string -> [ `Tex of string | `Newick of string | `TextList of (string * int) list ] end
module InputHandler : InputHandler = struct
  let handle input =
    if String.contains input '(' then `Newick input
    else if String.contains input '\\' then `Tex input
    else let lines = String.split_on_char '\n' input in
         let timestamped = List.mapi (fun i line -> (line, i)) lines in `TextList timestamped
end
EOF
fi

if [ ! -f "preprocess.ml" ]; then
    cat > preprocess.ml << 'EOF'
open Types
module type Preprocessor = sig val preprocess: [ `Tex of string | `Newick of string | `TextList of (string * int) list ] -> document end
module TextPreprocessor : Preprocessor = struct
  let levenshtein s1 s2 =
    let m = String.length s1 and n = String.length s2 in
    let d = Array.make_matrix (m + 1) (n + 1) 0 in
    for i = 0 to m do d.(i).(0) <- i done;
    for j = 0 to n do d.(0).(j) <- j done;
    for i = 1 to m do
      for j = 1 to n do
        let cost = if s1.[i-1] = s2.[j-1] then 0 else 1 in
        d.(i).(j) <- min (d.(i-1).(j) + 1) (min (d.(i).(j-1) + 1) (d.(i-1).(j-1) + cost))
      done
    done;
    float_of_int d.(m).(n)
  let upgma distances taxa =
    let rec cluster matrix active =
      if List.length active <= 1 then List.hd active
      else
        let (i, j, min_dist) = List.fold_left (fun (mi, mj, md) (i, row) ->
          List.fold_left (fun (mi, mj, md) (j, d) ->
            if i < j && d < md then (i, j, d) else (mi, mj, md))
          (mi, mj, md) (List.mapi (fun j d -> (j, d)) row))
          (0, 1, infinity) (List.mapi (fun i row -> (i, row)) matrix)
        in
        let height = min_dist /. 2.0 in
        let new_node = Node ("phenetictree", [], { default_phylo with phenetic_distance = Some height },
          [List.nth active i; List.nth active j])
        in
        let new_active = List.filteri (fun k _ -> k <> i && k <> j) active @ [new_node] in
        let new_matrix = List.mapi (fun k row ->
          if k = i || k = j then List.map (fun _ -> infinity) row
          else List.mapi (fun l d ->
            if l = i || l = j then
              (List.nth (List.nth matrix k) i +. List.nth (List.nth matrix k) j) /. 2.0
            else d) row) matrix
        in
        cluster new_matrix new_active
    in
    let leaves = List.map (fun (t, ts) -> Leaf (t, { default_phylo with taxon = Some t; timestamp = Some ts })) taxa in
    let distances_matrix = List.map (fun (t1, _) -> List.map (fun (t2, _) -> levenshtein t1 t2) taxa) taxa in
    cluster distances_matrix leaves
  let extract_text = function
    | `Tex tex -> List.mapi (fun i line -> (line, i)) (String.split_on_char '\n' tex)
    | `Newick newick -> List.mapi (fun i line -> (line, i)) (String.split_on_char ',' newick)
    | `TextList list -> list
  let preprocess input =
    let text_list = extract_text input in
    let phenetic_tree = upgma (List.map (fun (t1, _) -> List.map (fun (t2, _) -> levenshtein t1 t2) text_list) text_list) text_list in
    { tree = Node ("document", [], default_phylo, [phenetic_tree]); meta = [] }
end
EOF
fi

if [ ! -f "lexer.ml" ]; then
    cat > lexer.ml << 'EOF'
open Types
module type Lexer = sig val tokenize: string -> token list end
module TexLexer : Lexer = struct
  let tokenize input =
    let rec aux pos acc =
      if pos >= String.length input then List.rev acc
      else match input.[pos] with
        | '\\' ->
            let cmd_end = String.index_from_opt input (pos + 1) '{' in
            let cmd = match cmd_end with
              | Some e -> String.sub input pos (e - pos)
              | None -> raise (ParseError (Printf.sprintf "Incomplete command at pos %d" pos))
            in
            aux (pos + String.length cmd) (Command cmd :: acc)
        | '{' -> aux (pos + 1) (LBrace :: acc)
        | '}' -> aux (pos + 1) (RBrace :: acc)
        | c ->
            let text_end = ref pos in
            while !text_end < String.length input && 
                  input.[!text_end] <> '\\' && input.[!text_end] <> '{' && input.[!text_end] <> '}' do
              incr text_end
            done;
            let text = String.sub input pos (!text_end - pos) in
            aux !text_end (Text text :: acc)
    in
    try aux 0 [] with e -> raise (ParseError (Printf.sprintf "Tokenization failed: %s" (Printexc.to_string e)))
end
module NewickLexer : Lexer = struct let tokenize input = [Text input] end
EOF
fi

if [ ! -f "parser.ml" ]; then
    cat > parser.ml << 'EOF'
open Types
module type Parser = sig val parse: token list -> document end
module TexParser : Parser = struct
  let rec parse_content i acc support_acc tokens =
    if i >= List.length tokens then (List.rev acc, i)
    else match List.nth tokens i with
      | Command "\\section" ->
          let (content, next_i) = parse_arg (i + 2) "section" tokens in
          parse_content next_i (Node ("section", [], default_phylo, [Leaf (content, default_phylo)]) :: acc) support_acc tokens
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
          let support = try Some (float_of_string value) with _ -> raise (ParseError "Invalid support value") in
          parse_content next_i acc support tokens
      | Text s -> parse_content (i + 1) (Leaf (s, default_phylo) :: acc) support_acc tokens
      | _ -> raise (ParseError (Printf.sprintf "Unexpected token at index %d" i))
  and parse_arg i context tokens =
    if i + 2 >= List.length tokens || List.nth tokens i <> LBrace || List.nth tokens (i + 2) <> RBrace then
      raise (ParseError (Printf.sprintf "Malformed argument for %s at index %d" context i))
    else match List.nth tokens (i + 1) with
      | Text s -> (s, i + 3)
      | _ -> raise (ParseError (Printf.sprintf "Expected text in %s argument at index %d" context i))
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
    let input = match tokens with [Text s] -> s | _ -> raise (ParseError "Invalid Newick input") in
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
        try aux (i + 1) [] with _ -> raise (ParseError (Printf.sprintf "Invalid length at pos %d" i))
    in
    try
      let (tree, _) = parse_subtree 0 in
      { tree = Node ("document", [], default_phylo, [tree]); meta = [] }
    with e -> raise (ParseError (Printf.sprintf "Newick parsing failed: %s" (Printexc.to_string e)))
end
EOF
fi

if [ ! -f "treeproc.ml" ]; then
    cat > treeproc.ml << 'EOF'
open Types
module type TreeProcessor = sig val process: document -> document -> document end
module TreeProcessor : TreeProcessor = struct
  let rec merge_trees phenetic structural =
    match (phenetic, structural) with
    | (Node ("phenetictree", _, p_phylo, p_children), Node ("document", s_meta, s_phylo, s_children)) ->
        Node ("document", s_meta, s_phylo, List.map2 (fun p s -> merge_trees p s) p_children s_children)
    | (Node (p_tag, p_meta, p_phylo, p_children), Node (s_tag, s_meta, s_phylo, s_children)) ->
        Node (s_tag, s_meta, { s_phylo with phenetic_distance = p_phylo.phenetic_distance }, List.map2 (fun p s -> merge_trees p s) p_children s_children)
    | (Leaf (p_text, p_phylo), Leaf (s_text, s_phylo)) ->
        Leaf (s_text, { s_phylo with phenetic_distance = p_phylo.phenetic_distance; timestamp = p_phylo.timestamp })
    | _ -> structural
  let process phenetic_doc structural_doc =
    { structural_doc with tree = merge_trees phenetic_doc.tree structural_doc.tree }
end
EOF
fi

if [ ! -f "generator.ml" ]; then
    cat > generator.ml << 'EOF'
open Types
module type Generator = sig val generate: document -> string end
module HtmlGenerator : Generator = struct
  let rec to_json = function
    | Node (tag, _, phylo, children) ->
        let name = match tag with
          | "document" -> "Book"
          | "section" -> "Section"
          | "tree" -> Printf.sprintf "Clade%s" (Option.value ~default:"" (Option.map (Printf.sprintf ":%.2f") phylo.branch_length))
          | "phenetictree" -> Printf.sprintf "Cluster%s" (Option.value ~default:"" (Option.map (Printf.sprintf ":%.2f") phylo.phenetic_distance))
          | _ -> tag
        in
        let support = Option.value ~default:"" (Option.map (Printf.sprintf " (%.2f)") phylo.support) in
        let timestamp = Option.value ~default:"" (Option.map (Printf.sprintf " [t=%d]") phylo.timestamp) in
        Printf.sprintf "{\"name\": \"%s%s%s\", \"children\": [%s]}" name support timestamp (String.concat "," (List.map to_json children))
    | Leaf (s, phylo) ->
        let taxon = Option.value ~default:s phylo.taxon in
        let support = Option.value ~default:"" (Option.map (Printf.sprintf " (%.2f)") phylo.support) in
        let timestamp = Option.value ~default:"" (Option.map (Printf.sprintf " [t=%d]") phylo.timestamp) in
        Printf.sprintf "{\"name\": \"%s%s%s\"}" taxon support timestamp
  let generate doc =
    let json_data = to_json doc.tree in
    Printf.sprintf "<!DOCTYPE html>
<html>
<head>
  <title>Web Graph</title>
  <script src=\"https://d3js.org/d3.v7.min.js\"></script>
  <style>
    .link { stroke-opacity: 0.6; }
    .node text { font: 12px sans-serif; }
  </style>
</head>
<body>
  <div id=\"graph\"></div>
  <script>
    const data = %s;
    const width = 600, height = 600;
    const svg = d3.select(\"#graph\").append(\"svg\").attr(\"width\", width).attr(\"height\", height);
    const tree = d3.tree().size([height - 50, width - 150]);
    const root = d3.hierarchy(data);
    tree(root);
    const link = svg.selectAll(\".link\")
      .data(root.links())
      .enter().append(\"path\")
      .attr(\"class\", \"link\")
      .attr(\"d\", d3.linkHorizontal()
        .x(d => d.y + 50)
        .y(d => d.x + 25))
      .attr(\"fill\", \"none\")
      .attr(\"stroke\", d => d.target.data.name.includes(\"Cluster\") ? \"blue\" : \"black\")
      .attr(\"stroke-dasharray\", d => d.target.data.name.includes(\"Cluster\") ? \"5,5\" : \"0\");
    const node = svg.selectAll(\".node\")
      .data(root.descendants())
      .enter().append(\"g\")
      .attr(\"class\", \"node\")
      .attr(\"transform\", d => `translate(${d.y + 50},${d.x + 25})`);
    node.append(\"text\")
      .attr(\"dy\", \".35em\")
      .attr(\"x\", d => d.children ? -10 : 10)
      .text(d => d.data.name)
      .style(\"text-anchor\", d => d.children ? \"end\" : \"start\");
    node.append(\"title\")
      .text(d => d.data.name);
  </script>
</body>
</html>" json_data
end
EOF
fi

if [ ! -f "main.ml" ]; then
    cat > main.ml << 'EOF'
open Types
open Input
open Preprocess
open Lexer
open Parser
open Treeproc
open Generator
let process_input input =
  let input_type = InputHandler.handle input in
  let phenetic = TextPreprocessor.preprocess input_type in
  let structural = match input_type with
    | `Tex tex -> TexParser.parse (TexLexer.tokenize tex)
    | `Newick newick -> NewickParser.parse (NewickLexer.tokenize newick)
    | `TextList _ -> phenetic
  in
  let processed = TreeProcessor.process phenetic structural in
  HtmlGenerator.generate processed
let () =
  let tex_input = "\\section{Phylogeny} \\support{0.95} \\tree{0.5}{\\taxon{A} \\taxon{B}}" in
  let newick_input = "(A:0.1,B:0.2):0.5" in
  let text_input = "cat\ndog\nrat" in
  try
    print_endline (process_input tex_input);
    print_endline (process_input newick_input);
    print_endline (process_input text_input)
  with ParseError msg -> Printf.printf "Error: %s\n" msg
EOF
fi

if [ ! -f "_tags" ]; then
    echo "<*.ml>: package(ocamlbuild)" > _tags
fi

# Compile the project
echo "Building the project..."
ocamlbuild -use-ocamlfind main.native

# Test cases
echo "Running tests..."

# Test 1: TeX Input
echo "Test 1: TeX Input"
echo "\\section{Phylogeny} \\support{0.95} \\tree{0.5}{\\taxon{A} \\taxon{B}}" > tex_input.txt
./main.native < tex_input.txt > tex_output.html
echo "TeX output written to tex_output.html"
head -n 10 tex_output.html

# Test 2: Newick Input
echo "Test 2: Newick Input"
echo "(A:0.1,B:0.2):0.5" > newick_input.txt
./main.native < newick_input.txt > newick_output.html  # Fixed typo here
echo "Newick output written to newick_output.html"
head -n 10 newick_output.html

# Test 3: Unstructured Text Input
echo "Test 3: Unstructured Text Input"
echo -e "cat\ndog\nrat" > text_input.txt
./main.native < text_input.txt > text_output.html
echo "Text output written to text_output.html"
head -n 10 text_output.html

echo "Tests complete. Outputs are in tex_output.html, newick_output.html, and text_output.html."
echo "Open these files in a browser to view the interactive web graphs."