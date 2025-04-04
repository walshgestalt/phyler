open Types
module type Preprocessor = sig val preprocess: [ `Tex of string | `Newick of string | `TextList 
of (string * int) list ] -> document end
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
        let new_node = Node ("phenetictree", [], { default_phylo with phenetic_distance = Some 
height },
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
    let leaves = List.map (fun (t, ts) -> Leaf (t, { default_phylo with taxon = Some t; timestamp 
= Some ts })) taxa in
    let distances_matrix = List.map (fun (t1, _) -> List.map (fun (t2, _) -> levenshtein t1 t2) 
taxa) taxa in
    cluster distances_matrix leaves
  let extract_text = function
    | `Tex tex -> List.mapi (fun i line -> (line, i)) (String.split_on_char '\n' tex)
    | `Newick newick -> List.mapi (fun i line -> (line, i)) (String.split_on_char ',' newick)
    | `TextList list -> list
  let preprocess input =
    let text_list = extract_text input in
    let phenetic_tree = upgma (List.map (fun (t1, _) -> List.map (fun (t2, _) -> levenshtein t1 
t2) text_list) text_list) text_list in
    { tree = Node ("document", [], default_phylo, [phenetic_tree]); meta = [] }
end
