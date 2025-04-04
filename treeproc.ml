open Types
module type TreeProcessor = sig val process: document -> document -> document end
module TreeProcessor : TreeProcessor = struct
  let rec merge_trees phenetic structural =
    match (phenetic, structural) with
    | (Node ("phenetictree", _, p_phylo, p_children), Node ("document", s_meta, s_phylo, 
s_children)) ->
        Node ("document", s_meta, s_phylo, List.map2 (fun p s -> merge_trees p s) p_children 
s_children)
    | (Node (p_tag, p_meta, p_phylo, p_children), Node (s_tag, s_meta, s_phylo, s_children)) ->
        Node (s_tag, s_meta, { s_phylo with phenetic_distance = p_phylo.phenetic_distance }, 
List.map2 (fun p s -> merge_trees p s) p_children s_children)
    | (Leaf (p_text, p_phylo), Leaf (s_text, s_phylo)) ->
        Leaf (s_text, { s_phylo with phenetic_distance = p_phylo.phenetic_distance; timestamp = 
p_phylo.timestamp })
    | _ -> structural
  let process phenetic_doc structural_doc =
    { structural_doc with tree = merge_trees phenetic_doc.tree structural_doc.tree }
end
