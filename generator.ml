open Types
module type Generator = sig val generate: document -> string end
module HtmlGenerator : Generator = struct
  let rec to_json = function
    | Node (tag, _, phylo, children) ->
        let name = match tag with
          | "document" -> "Book"
          | "section" -> "Section"
          | "tree" -> Printf.sprintf "Clade%s" (Option.value ~default:"" (Option.map 
(Printf.sprintf ":%.2f") phylo.branch_length))
          | "phenetictree" -> Printf.sprintf "Cluster%s" (Option.value ~default:"" (Option.map 
(Printf.sprintf ":%.2f") phylo.phenetic_distance))
          | _ -> tag
        in
        let support = Option.value ~default:"" (Option.map (Printf.sprintf " (%.2f)") 
phylo.support) in
        let timestamp = Option.value ~default:"" (Option.map (Printf.sprintf " [t=%d]") 
phylo.timestamp) in
        Printf.sprintf "{\"name\": \"%s%s%s\", \"children\": [%s]}" name support timestamp 
(String.concat "," (List.map to_json children))
    | Leaf (s, phylo) ->
        let taxon = Option.value ~default:s phylo.taxon in
        let support = Option.value ~default:"" (Option.map (Printf.sprintf " (%.2f)") 
phylo.support) in
        let timestamp = Option.value ~default:"" (Option.map (Printf.sprintf " [t=%d]") 
phylo.timestamp) in
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
    const svg = d3.select(\"#graph\").append(\"svg\").attr(\"width\", width).attr(\"height\", 
height);
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
      .attr(\"stroke-dasharray\", d => d.target.data.name.includes(\"Cluster\") ? \"5,5\" : 
\"0\");
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
