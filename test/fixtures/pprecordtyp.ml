open Camlp4.PreCast

let _loc = Loc.mk "?"

let base base fields ty =
  let fields = List.fold_right (fun field acc ->
    let c = <:ctyp< $lid:field$ : $uid:field$.record >> in
    <:ctyp< $c$ ; $acc$ >>) fields <:ctyp< >>
  in
  <:module_binding< $uid:base$ :
    sig type record = {
        key : $ty$;
        $fields$
      } end = struct
        type record = {
        key : $ty$;
        $fields$
      } end
    >>

module CleanAst = Camlp4.Struct.CleanAst.Make(Ast)
let _ =
  let b = base "b" ["f1"; "f2"] <:ctyp< int >> in
  Camlp4.PreCast.Printers.OCaml.print_implem
    ((new CleanAst.clean_ast)#str_item
      <:str_item< module rec $b$ >>)
