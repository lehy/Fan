#default_quotation "ctyp";;

open Ast
open AstLib
open LibUtil

open Basic
open FSig

let arrow_of_list = List.reduce_right arrow
    
let app_arrow lst acc = List.fold_right arrow lst acc
    
let (<+) (names: string list ) (ty:ctyp) =
  let _loc = FanLoc.ghost in
  List.fold_right (fun name acc -> {| '$lid:name -> $acc |}) names ty
    
let (+>) (params: ctyp list ) (base:ctyp) = List.fold_right arrow params base

(*
  {[
  match <:stru< type 'a list  = [A of int | B of 'a] >> with
  [ <:stru<type .$x$. >> -> name_length_of_tydcl x ];
  ("list",1)
  ]}
 *)
let name_length_of_tydcl (x:typedecl) : (string * int) =
  match x with 
  | `TyDcl (_, `Lid(_,name), tyvars, _, _) ->
      (name, match tyvars with |`None _ -> 0 | `Some (_,xs) -> List.length & list_of_com  xs [])
  | tydcl ->
      failwithf "name_length_of_tydcl {|%s|}\n"  (Objs.dump_typedecl tydcl)



(*
  generate universal quantifiers for object's type signatures
  {[

  gen_quantifiers ~arity:2 3 |> eprint;
  'all_a0 'all_a1 'all_a2 'all_b0 'all_b1 'all_b2
  ]}
  quantifier variables can not be unified
 *)  
let gen_quantifiers1 ~arity n  : ctyp =
  let _loc = FanLoc.ghost in
  List.init arity
    (fun i -> List.init n (fun j -> {|  '$(lid:allx ~off:i j) |} ))
  |> List.concat |> appl_of_list


(*
  {[
  of_id_len ~off:2 (<:ident< Loc.t >> , 3 ) |> eprint;
  Loc.t 'all_c0 'all_c1 'all_c2
  ]}
 *)  
let of_id_len ~off ((id:ident),len) =
  let _loc = FanLoc.ghost in 
  appl_of_list
    ((id:>ctyp) ::
     List.init len
       (fun i -> {|  '$(lid:allx ~off i) |}))
    
(*
  {[
  ( <:stru< type 'a list  = [A of int | B of 'a] >> |>
  fun [ <:stru<type .$x$. >> -> name_length_of_tydcl x
  |> of_name_len ~off:1 |> eprint ] );
  list 'all_b0

  ( <:stru< type list   = [A of int | B] >> |>
  fun [ <:stru<type .$x$. >> -> name_length_of_tydcl x
  |> of_name_len ~off:1 |> eprint ] );
  ]}

 *)    

let of_name_len ~off (name,len) =
  let _loc = FanLoc.ghost in
  let id = {:ident| $lid:name |}  in
  of_id_len ~off (id,len)



(*
  {[
  (fun [ <:stru<type .$x$. >> -> gen_ty_of_tydcl ~off:2 x  |> eprint ])
  <:stru< type list 'a 'b = [A of int | B of 'a] >> ;

  list 'all_c0 'all_c1
  ]}
 *)  
let gen_ty_of_tydcl ~off (tydcl:typedecl) =
  tydcl |> name_length_of_tydcl |>of_name_len ~off 
    
(*
  @raise Invalid_argument 

  {[
  list_of_record {:ctyp| u:int;m:mutable int |};
  - : FSig.col list =
  [{label = "u"; is_mutable = false; ctyp = Id (, Lid (, "int"))};
  {label = "m"; is_mutable = true; ctyp = Id (, Lid (, "int"))}]
  ]}
  
 *)
let list_of_record (ty:name_ctyp) : FSig.col list  =
  let (tys : name_ctyp list )  = list_of_sem ty [] in
  (* list_of_sem' ty [] *) tys|> List.map (
  function
    |
      (* {| $lid:label : mutable $ctyp  |} *)
      (* `TyCol (_, (`Id (_, (`Lid (_, col_label)))), (`Mut (_, col_ctyp))) -> *)
      `TyColMut(_,`Lid(_,col_label),col_ctyp) ->
        {col_label; col_ctyp; col_mutable=true}
    | `TyCol (_, `Lid (_, col_label), col_ctyp)
        (* {| $lid:label :  $ctyp  |} *) -> 
          {col_label; col_ctyp; col_mutable=false}
    | t0 ->
        FanLoc.errorf (loc_of t0)
          "list_of_record %s" (Objs.dump_name_ctyp t0) )

    
(*
  @raise Invalid_argument 
  {[
  gen_tuple_n {| int |} 3  |> eprint;
  (int * int * int)
  gen_tuple_n {| int |} 1  |> eprint;
  int
  ]}
 *)
let gen_tuple_n ty n = List.init n (fun _ -> ty) |> tuple_sta

(*
  {[
  repeat_arrow_n <:ctyp< 'a >> 3 |> eprint;
  'a -> 'a -> 'a
  ]}
 *)
let repeat_arrow_n ty n =
  List.init n (fun _ -> ty) |>  arrow_of_list
    

(* to be clean soon *)
let result_id = ref 0 
    
let mk_method_type ~number ~prefix (id,len) (k:destination) : (ctyp * ctyp) =
  (** FIXME A type variable name need to be valid *)
  let _loc = FanLoc.ghost in
  let prefix = List.map
      (fun s -> String.drop_while (fun c -> c = '_') s) prefix in 
  let app_src   =
    app_arrow (List.init number (fun _ -> (of_id_len ~off:0 (id,len)))) in
  let result_type = (* {| 'result |} *)
    {|'$(lid:"result"^string_of_int !result_id)|} in
  let _ = incr result_id in
  let self_type = {| 'self_type |}  in 
  let (quant,dst) =
    match k with
    |Obj Map -> (2, (of_id_len ~off:1 (id,len)))
    |Obj Iter -> (1, result_type)
    |Obj Fold -> (1, self_type)
    |Obj (Concrete c ) -> (1,c)
    (* |Type c -> (1,c)  *)
    |Str_item -> (1,result_type) in 
  let params =
    List.init len
      (fun i
        ->
          let app_src = app_arrow
              (List.init number
                 (fun _ -> {|  '$(lid:allx ~off:0 i)  |} )) in
          match k with
          |Obj u  ->
              let dst =
                match  u with
                | Map -> {|  '$(lid:allx ~off:1 i) |}
                | Iter -> result_type
                | Concrete c -> c
                | Fold-> self_type  in
              (arrow self_type  (prefix <+ (app_src dst)))
          |Str_item -> prefix <+ app_src result_type
          (* |Type _  -> prefix <+ app_src dst *)
      ) in 
  let base = prefix <+ (app_src dst) in
  if len = 0 then
    ( `TyPolEnd (_loc, base),dst)
  else let quantifiers = gen_quantifiers1 ~arity:quant len in
  ({| ! $quantifiers . $(params +> base) |},dst)



(* *)  
let mk_method_type_of_name ~number ~prefix (name,len) (k:destination)  =
  let _loc = FanLoc.ghost in
  let id = {:ident| $lid:name |} in
  mk_method_type ~number ~prefix (id,len) k 


let mk_obj class_name  base body =
  let _loc = FanLoc.ghost in
  {:stru|
   class $lid:class_name = object (self: 'self_type)
     inherit $lid:base ;
     $body;
   end |}

    
let is_recursive ty_dcl =
  match ty_dcl with
  | `TyDcl (_, `Lid(_,name), _, ctyp, _)  ->
      let obj = object(self:'self_type)
        inherit Objs.fold as super;
        val mutable is_recursive = false;
        method! ctyp = function
          | {| $lid:i |} when i = name -> begin 
              is_recursive <- true;
              self
          end 
          | x ->  if is_recursive then  self
          else super#ctyp x  
        method is_recursive = is_recursive
      end in
      (obj#type_info(* ctyp *) ctyp)#is_recursive

  | `And(_,_,_)  -> true (* FIXME imprecise *)
  | _ -> failwithf "is_recursive not type declartion: %s" (Objs.dump_typedecl ty_dcl)

(*
  {:stru|
  type u = int
  and v = bool
  |}
 *)
(*
  detect patterns like [List.t int ] or [List.t]
  Here the order matters
  {[
  ( {:sigi| type 'a tbl  = Ident.tbl 'a |} |> fun
  [ <:sigi< type .$FanAst.TyDcl _loc _ _ x _ $. >>
  -> qualified_app_list x ]);
  Some (IdAcc  (Uid  "Ident") (Lid  "tbl"), [TyQuo  "a"])
  ]}
  
 *)  
let qualified_app_list x : ((ident * ctyp list ) option ) =
  match x with 
  | {| $_ $_ |} as x->
      begin match list_of_app x [] with
      | {| $lid:_  |} :: _  -> None
      | (#ident' as i) ::ys  ->
          Some (i,ys)
      | _ -> None
      end
  | `Lid _ | `Uid _  -> None
  | #ident'  as i  -> Some (i, [])
  | _ -> None 

let is_abstract (x:typedecl)=
  match x with
  | `TyAbstr _ -> true
  | _ -> false
        (* [ `TyDcl (_, _, _, {| |}, _) -> true | _ -> false]; *)

let abstract_list (x:typedecl)=
  match x with 
  | `TyAbstr (_, _, lst,  _) ->
      begin match lst with
      | `None _ -> Some 0
      |`Some (_,xs) ->
          Some (List.length & list_of_com xs [])
      end
        (* Some (List.length lst) *)
  | _ -> None
        
let eq t1 t2 =
  let strip_locs t = (Objs.map_loc (fun _ -> FanLoc.ghost))#ctyp t in
  strip_locs t1 = strip_locs t2

    
(* FIXME add hoc *)  
let eq_list t1 t2 =
  let rec loop = function
    | ([],[]) -> true
    | (x::xs,y::ys) -> eq x y && loop (xs,ys)
    | (_,_) -> false in loop (t1,t2)
    
(*

  {[

  let f = mk_transform_type_eq ();

  let v =
  (f#stru

  <:stru<
  type a = Loc.t
  and  b 'a  = [ A of LL.t 'a and LL.t 'a and Loc.t];
  let f x = 3
  >> );

  f#type_transformers |>  opr#stru fmt;  

  v |> opr#stru fmt;

  type ll_t 'a0 = LL.t 'a0;
  type loc_t = Loc.t;
  type a = loc_t and b 'a = [ A of ll_t 'a and ll_t 'a and loc_t ];
  let f x = 3;
  
  ]}
  There are two cases:
  The first is [Loc.t => loc_t], and record the relationship to the hashtbl.
  It's reasonalble and sound. But it may bring some unnecessary duplicated code.

  We only consider one duplicated case
  [type u 'a = Loc.t 'a] [type u int = Loc.t int ]
  the type variables are the same as the type definition.
  here we record the relationship [Loc.t => u ]
  ]}
 *)
let mk_transform_type_eq () = object(self:'self_type)
  val transformers = Hashtbl.create 50
  inherit Objs.map as super
  method! stru = function
    | {:stru| type $(`TyDcl (_, _name, vars, ctyp, _) ) |} as x -> (* FIXME why tuple?*)
        let r =
          match ctyp with
          | `TyEq (_,_,t) -> qualified_app_list t | _ -> None  in
        begin match  r with
        | Some (i,lst)  -> (* [ type u 'a = Loc.t int U.float]*)
            let vars =
              match vars with 
              | `None _ -> [] | `Some (_,x) -> list_of_com x [] in
            if  not (eq_list (vars : decl_params list  :>  ctyp list) lst) then 
              super#stru x
            else
              (* Manual substitution
                 [type u 'a 'b = Loc.t 'a 'b]
                 [type u int = Loc.t int]
                 This case can not happen [type u FanAst.int = Loc.t FanAst.int ]
               *)
              let src = i and dest =             
                Id.to_string i in begin
                  Hashtbl.replace transformers dest (src,List.length lst);
                  {:stru| let _ = ()|} (* FIXME *)
                end 
        | None ->  super#stru x
        end
    | x -> super#stru x 
  method! ctyp x =
    let _loc = FanLoc.ghost in
    match qualified_app_list x with
    | Some (i, lst) ->
        let lst = List.map (fun ctyp -> self#ctyp ctyp) lst in 
        let src = i and dest = Id.to_string i in begin
          Hashtbl.replace transformers dest (src,List.length lst);
          appl_of_list ({| $lid:dest |} :: lst )
        end
    | None -> super#ctyp x
          (* dump the type declarations *)  
  method type_transformers = 
    Hashtbl.fold (fun dest (src,len) acc ->
      (dest,src,len)  :: acc) transformers []

end



(*
  This is a general tranversal, which could be bootstrapped
  using our pluggin actually
  Preprocess mtyps, generate type equalities

 *)
let transform_mtyps  (lst:FSig.mtyps) =
  let obj = mk_transform_type_eq () in 
  let item1 =
    List.map (function
      |`Mutual ls ->
          `Mutual (List.map
                     (fun (s,ty) ->
                       (s, obj#typedecl ty)) ls)
      |`Single (s,ty) ->
          `Single (s, obj#typedecl ty)) lst in
  let new_types = obj#type_transformers in
  (new_types,item1)
    
(* 
   {[
   reduce_data_ctors
   {:ctyp| A of option int and float | B of float |} []
   (fun  s xs acc ->
   (prerr_endline s;  [xs :: acc] ))  ;
   A
   B
   Id  (Lid  "float");
   App  (Id  (Lid  "option")) (Id  (Lid  "int"));
   Id  (Lid  "float")
   ]}
   @return result type to indicate error
   FIXME a good  support for arrow types?
   FIXME moved to astbuild?
   [ A of [`a | `b] and int ]
 *)
let reduce_data_ctors (ty:or_ctyp)  (init:'a) ~compose
    (f:  string -> ctyp list  -> 'e)  =
  let branches = list_of_or ty [] in
  List.fold_left
    (fun acc x ->
      match (x:or_ctyp) with
      |  `Of (_loc, `Uid (_, cons), tys)
        ->
          compose (f cons (list_of_star tys [])) acc  
      | (* {| $uid:cons |} *)
        `Uid (_, cons)
        -> compose  (f cons [] ) acc
      | t->
          FanLoc.errorf (loc_of t)
            "reduce_data_ctors: %s" (Objs.dump_or_ctyp t)) init  branches
    
let view_sum (t:or_ctyp) =
  let bs = list_of_or t [] in
  List.map
    (function
      | (* {|$uid:cons|} *) `Uid(_,cons) ->
          `branch (cons,[])
      | `Of(_loc,`Uid(_,cons),t) (* {|$uid:cons of $t|} *) ->
          `branch (cons,  list_of_star  t [])
      | _ -> assert false ) bs 

(*
  {[
  reduce_variant {:ctyp| [ `Chr of (loc * string) (* 'c' *)
  | `Int of   (loc * string) (* 42 *)
  | `Int32 of (loc * string)
  | `Int64 of (loc * string)
  | `Flo of (loc * string)
  | `Nativeint of (loc * string)
  (* s *) (* "foo" *)
  | `Str of (loc * string) | u | list int | [ `b | `c ] ] |};

  type v = [ `b];
  type u = [ `a | v ];
  let pp_print_u = function
  [ `a -> pp_print "%a"
  | #v -> pp_print_v 
  ]
  ]}
 *)    
let view_variant (t:row_field) : vbranch list  =
  let lst = list_of_or t [] in 
  List.map (
  function
    | (* {| $vrn:cons of $par:t |} *)
      (* `Of (_loc, (`TyVrn (_, `C (_,cons))), (`Par (_, t))) *)
      `TyVrnOf(_loc, `C(_,cons), `Par(_,t))
      ->
        `variant (cons, list_of_star t [])
    | (* {| `$cons of $t |} *)
      (* `Of (_loc, (`TyVrn (_, `C(_,cons))), t) *)
      `TyVrnOf(_loc,`C(_,cons),t)
      -> `variant (cons, [t])
    | (* {| `$cons |} *)
      `TyVrn (_loc, `C (_,cons))
      ->
        `variant (cons, [])
    | `Ctyp (_ , (#ident' as i) ) -> 
        (* |  `Id (_loc,i) -> *) `abbrev i  
          (* | {|$lid:x|} -> `abbrev x  *)
    | u -> FanLoc.errorf (loc_of u)
          "view_variant %s" (Objs.dump_row_field u)  ) lst 

    



(*
  @raise Invalid_argument  when the input is not a type declaration

  {[
  
  (fun [ <:stru<type .$x$. >> -> ty_name_of_tydcl x  |> eprint ])
  <:stru< type list 'a  = [A of int | B of 'a] >>;

  list 'a
  ]}
 *)  
(* let ty_name_of_tydcl  (x:typedecl) = *)
(*   let _loc = FanLoc.ghost in *)
(*   match x with  *)
(*   | `TyDcl (_, `Lid(_,name), tyvars, _, _) -> *)
(*       let tyvars = *)
(*         match tyvars with *)
(*         | `None _ -> [] *)
(*         |`Some(_,xs) -> (list_of_com xs [] :>  ctyp list)  in *)
(*       appl_of_list ( {| $lid:name |} :: tyvars) *)
(*   | tydcl -> *)
(*       failwithf "ctyp_of_tydcl{|%s|}\n" (Objs.dump_typedecl tydcl) *)
        
