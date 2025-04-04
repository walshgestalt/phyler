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
                  input.[!text_end] <> '\\' && input.[!text_end] <> '{' && input.[!text_end] <> 
'}' do
              incr text_end
            done;
            let text = String.sub input pos (!text_end - pos) in
            aux !text_end (Text text :: acc)
    in
    try aux 0 [] with e -> raise (ParseError (Printf.sprintf "Tokenization failed: %s" 
(Printexc.to_string e)))
end
module NewickLexer : Lexer = struct let tokenize input = [Text input] end
