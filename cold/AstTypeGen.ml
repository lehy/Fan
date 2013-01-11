open Ast
open LibUtil
open Easy
open FSig
open Lib.Expr
let _loc = FanLoc.ghost
let mk_variant_eq _cons =
  (function
   | [] -> `Id (_loc, (`Lid (_loc, "true")))
   | ls ->
       List.reduce_left_with
         ~compose:(fun x  y  ->
                     `ExApp
                       (_loc,
                         (`ExApp (_loc, (`Id (_loc, (`Lid (_loc, "&&")))), x)),
                         y)) ~f:(fun { expr;_}  -> expr) ls : FSig.ty_info
                                                                list -> 
                                                                expr )
let mk_tuple_eq exprs = mk_variant_eq "" exprs
let mk_record_eq: FSig.record_col list -> expr =
  fun cols  ->
    (cols |> (List.map (fun { info;_}  -> info))) |> (mk_variant_eq "")
let (gen_eq,gen_eqobj) =
  ((gen_str_item ~id:(`Pre "eq_") ~names:[] ~arity:2 ~mk_tuple:mk_tuple_eq
      ~mk_record:mk_record_eq ~mk_variant:mk_variant_eq
      ~trail:(`Id (_loc, (`Lid (_loc, "false")))) ()),
    (gen_object ~kind:Iter ~mk_tuple:mk_tuple_eq ~mk_record:mk_record_eq
       ~base:"eqbase" ~class_name:"eq" ~mk_variant:mk_variant_eq ~names:[]
       ~arity:2 ~trail:(`Id (_loc, (`Lid (_loc, "false")))) ()))
let _ = [("Eq", gen_eq); ("OEq", gen_eqobj)] |> (List.iter Typehook.register)
let (gen_fold,gen_fold2) =
  let mk_variant _cons params =
    (params |> (List.map (fun { expr;_}  -> expr))) |>
      (function
       | [] -> `Id (_loc, (`Lid (_loc, "self")))
       | ls ->
           List.reduce_right
             (fun v  acc  ->
                `LetIn
                  (_loc, (`ReNil _loc),
                    (`Bind (_loc, (`Id (_loc, (`Lid (_loc, "self")))), v)),
                    acc)) ls) in
  let mk_tuple = mk_variant "" in
  let mk_record cols =
    (cols |> (List.map (fun { info;_}  -> info))) |> (mk_variant "") in
  ((gen_object ~kind:Fold ~mk_tuple ~mk_record ~base:"foldbase"
      ~class_name:"fold" ~mk_variant ~names:[] ()),
    (gen_object ~kind:Fold ~mk_tuple ~mk_record ~base:"foldbase2"
       ~class_name:"fold2" ~mk_variant ~names:[] ~arity:2
       ~trail:(`ExApp
                 (_loc, (`Id (_loc, (`Lid (_loc, "invalid_arg")))),
                   (`Str (_loc, "fold2 failure")))) ()))
let _ =
  [("Fold", gen_fold); ("Fold2", gen_fold2)] |> (List.iter Typehook.register)
let (gen_map,gen_map2) =
  let mk_variant cons params =
    let result =
      (params |> (List.map (fun { exp0;_}  -> exp0))) |>
        (apply (of_str cons)) in
    List.fold_right
      (fun { expr; pat0;_}  res  ->
         `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res))
      params result in
  let mk_tuple params =
    let result =
      (params |> (List.map (fun { exp0;_}  -> exp0))) |> tuple_of_list in
    List.fold_right
      (fun { expr; pat0;_}  res  ->
         `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res))
      params result in
  let mk_record cols =
    let result =
      (cols |>
         (List.map (fun { label; info = { exp0;_};_}  -> (label, exp0))))
        |> mk_record in
    List.fold_right
      (fun { info = { expr; pat0;_};_}  res  ->
         `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res)) cols
      result in
  ((gen_object ~kind:Map ~mk_tuple ~mk_record ~base:"mapbase"
      ~class_name:"map" ~mk_variant ~names:[] ()),
    (gen_object ~kind:Map ~mk_tuple ~mk_record ~base:"mapbase2"
       ~class_name:"map2" ~mk_variant ~names:[] ~arity:2
       ~trail:(`ExApp
                 (_loc, (`Id (_loc, (`Lid (_loc, "invalid_arg")))),
                   (`Str (_loc, "map2 failure")))) ()))
let _ =
  [("Map", gen_map); ("Map2", gen_map2)] |> (List.iter Typehook.register)
let gen_strip =
  let mk_variant cons params =
    let result =
      ((List.tl params) |> (List.map (fun { exp0;_}  -> exp0))) |>
        (apply (of_str cons)) in
    List.fold_right
      (fun { expr; pat0; ty;_}  res  ->
         match ty with
         | `Id (_loc,`Lid (_,"int"))|`Id (_loc,`Lid (_,"string"))
           |`Id (_loc,`Lid (_,"int32"))|`Id (_loc,`Lid (_,"nativeint"))
           |`Id (_loc,`Lid (_,"loc"))
           |`TyApp (_loc,`Id (_,`Lid (_,"list")),`Id (_,`Lid (_,"string")))
           |`TyApp
              (_loc,`Id (_,`Lid (_,"meta_list")),`Id (_,`Lid (_,"string")))
             -> res
         | _ -> `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res))
      (List.tl params) result in
  let mk_tuple params =
    let result =
      (params |> (List.map (fun { exp0;_}  -> exp0))) |> tuple_of_list in
    List.fold_right
      (fun { expr; pat0; ty;_}  res  ->
         match ty with
         | `Id (_loc,`Lid (_,"int"))|`Id (_loc,`Lid (_,"string"))
           |`Id (_loc,`Lid (_,"int32"))|`Id (_loc,`Lid (_,"nativeint"))
           |`Id (_loc,`Lid (_,"loc"))
           |`TyApp (_loc,`Id (_,`Lid (_,"list")),`Id (_,`Lid (_,"string")))
           |`TyApp
              (_loc,`Id (_,`Lid (_,"meta_list")),`Id (_,`Lid (_,"string")))
             -> res
         | _ -> `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res))
      params result in
  let mk_record cols =
    let result =
      (cols |>
         (List.map (fun { label; info = { exp0;_};_}  -> (label, exp0))))
        |> mk_record in
    List.fold_right
      (fun { info = { expr; pat0; ty;_};_}  res  ->
         match ty with
         | `Id (_loc,`Lid (_,"int"))|`Id (_loc,`Lid (_,"string"))
           |`Id (_loc,`Lid (_,"int32"))|`Id (_loc,`Lid (_,"nativeint"))
           |`Id (_loc,`Lid (_,"loc"))
           |`TyApp (_loc,`Id (_,`Lid (_,"list")),`Id (_,`Lid (_,"string")))
           |`TyApp
              (_loc,`Id (_,`Lid (_,"meta_list")),`Id (_,`Lid (_,"string")))
             -> res
         | _ -> `LetIn (_loc, (`ReNil _loc), (`Bind (_loc, pat0, expr)), res))
      cols result in
  gen_str_item ~id:(`Pre "strip_loc_") ~mk_tuple ~mk_record ~mk_variant
    ~names:[] ()
let _ = Typehook.register ~filter:(fun s  -> s <> "loc") ("Strip", gen_strip)
let mk_variant_meta_expr cons params =
  let len = List.length params in
  if String.ends_with cons "Ant"
  then of_vstr_number "Ant" len
  else
    (params |> (List.map (fun { expr;_}  -> expr))) |>
      (List.fold_left mee_app (mee_of_str cons))
let mk_record_meta_expr cols =
  (cols |> (List.map (fun { label; info = { expr;_};_}  -> (label, expr))))
    |> mk_record_ee
let mk_tuple_meta_expr params =
  (params |> (List.map (fun { expr;_}  -> expr))) |> mk_tuple_ee
let gen_meta_expr =
  gen_str_item ~id:(`Pre "meta_") ~names:["_loc"]
    ~mk_tuple:mk_tuple_meta_expr ~mk_record:mk_record_meta_expr
    ~mk_variant:mk_variant_meta_expr ()
let mk_variant_meta_patt cons params =
  let len = List.length params in
  if String.ends_with cons "Ant"
  then of_vstr_number "Ant" len
  else
    (params |> (List.map (fun { expr;_}  -> expr))) |>
      (List.fold_left mep_app (mep_of_str cons))
let mk_record_meta_patt cols =
  (cols |> (List.map (fun { label; info = { expr;_};_}  -> (label, expr))))
    |> mk_record_ep
let mk_tuple_meta_patt params =
  (params |> (List.map (fun { expr;_}  -> expr))) |> mk_tuple_ep
let gen_meta_patt =
  gen_str_item ~id:(`Pre "meta_") ~names:["_loc"]
    ~mk_tuple:mk_tuple_meta_patt ~mk_record:mk_record_meta_patt
    ~mk_variant:mk_variant_meta_patt ()
let _ =
  Typehook.register ~position:"__MetaExpr__" ~filter:(fun s  -> s <> "loc")
    ("MetaExpr", gen_meta_expr)
let _ =
  Typehook.register ~position:"__MetaPatt__" ~filter:(fun s  -> s <> "loc")
    ("MetaPatt", gen_meta_patt)
let extract info =
  (info |> (List.map (fun { name_expr; id_expr;_}  -> [name_expr; id_expr])))
    |> List.concat
let mkfmt pre sep post fields =
  `ExApp
    (_loc,
      (`ExApp
         (_loc,
           (`Id
              (_loc,
                (`IdAcc
                   (_loc, (`Uid (_loc, "Format")), (`Lid (_loc, "fprintf")))))),
           (`Id (_loc, (`Lid (_loc, "fmt")))))),
      (`Str (_loc, (pre ^ ((String.concat sep fields) ^ post)))))
let mk_variant_print cons params =
  let len = List.length params in
  let pre =
    if len >= 1
    then
      mkfmt ("@[<1>(" ^ (cons ^ "@ ")) "@ " ")@]"
        (List.init len (fun _  -> "%a"))
    else mkfmt cons "" "" [] in
  (params |> extract) |> (apply pre)
let mk_tuple_print params =
  let len = List.length params in
  let pre = mkfmt "@[<1>(" ",@," ")@]" (List.init len (fun _  -> "%a")) in
  (params |> extract) |> (apply pre)
let mk_record_print cols =
  let pre =
    (cols |> (List.map (fun { label;_}  -> label ^ ":%a"))) |>
      (mkfmt "@[<hv 1>{" ";@," "}@]") in
  ((cols |> (List.map (fun { info;_}  -> info))) |> extract) |> (apply pre)
let gen_print =
  gen_str_item ~id:(`Pre "pp_print_") ~names:["fmt"] ~mk_tuple:mk_tuple_print
    ~mk_record:mk_record_print ~mk_variant:mk_variant_print ()
let gen_print_obj =
  gen_object ~kind:Iter ~mk_tuple:mk_tuple_print ~base:"printbase"
    ~class_name:"print" ~names:["fmt"] ~mk_record:mk_record_print
    ~mk_variant:mk_variant_print ()
let _ =
  [("Print", gen_print); ("OPrint", gen_print_obj)] |>
    (List.iter Typehook.register)
let mk_variant_iter _cons params =
  (let lst =
     params |>
       (List.map
          (fun { name_expr; id_expr;_}  -> `ExApp (_loc, name_expr, id_expr))) in
   `Seq (_loc, (FanAst.exSem_of_list lst)) : expr )
let mk_tuple_iter params = (mk_variant_iter "" params : expr )
let mk_record_iter cols =
  let lst =
    cols |>
      (List.map
         (fun { info = { name_expr; id_expr;_};_}  ->
            `ExApp (_loc, name_expr, id_expr))) in
  `Seq (_loc, (FanAst.exSem_of_list lst))
let gen_iter =
  gen_object ~kind:Iter ~base:"iterbase" ~class_name:"iter" ~names:[]
    ~mk_tuple:mk_tuple_iter ~mk_record:mk_record_iter
    ~mk_variant:mk_variant_iter ()
let _ = ("OIter", gen_iter) |> Typehook.register