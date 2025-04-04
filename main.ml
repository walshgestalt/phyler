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
