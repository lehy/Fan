
(** dumping Fan's abstract syntax into OCaml's parsetree *)
  
open FAst
open Format
  
val mkvirtual : flag -> Asttypes.virtual_flag
val mkdirection : flag -> Asttypes.direction_flag
val mkrf : flag -> Asttypes.rec_flag


(**
  val ident_tag: ident -> Longident.t * [> `app | `lident | `uident ]
  {[
  ident_tag {:ident| $(uid:"").B.t|}
  - : Longident.t * [> `app | `lident | `uident ] =
  (Longident.Ldot (Longident.Lident "B", "t"), `lident)

  ident_tag {:ident| A B |}
  (Longident.Lapply (Longident.Lident "A", Longident.Lident "B"), `app)

  ident_tag {:ident| (A B).t|}
  (Longident.Ldot
  (Longident.Lapply (Longident.Lident "A", Longident.Lident "B"), "t"),
  `lident)

  ident_tag {:ident| B.C |}
  (Longident.Ldot (Longident.Lident "B", "C"), `uident)

  ident_tag {:ident| B.u.g|}
  Exception: FLoc.Exc_located (, Failure "invalid long identifier").
  ]}

  If "", just remove it, this behavior should appear in other identifier as well FIXME

 *)    
val ident_tag : ident -> Longident.t * [> `app | `lident | `uident ]

val ident_noloc : ident -> Longident.t

val ident : ident -> Longident.t Location.loc

val long_lident :  ident -> Longident.t Location.loc

val long_type_ident : ident -> Longident.t Location.loc

val long_class_ident : ident -> Longident.t Location.loc

val long_uident_noloc : ident -> Longident.t

val long_uident : ident -> Longident.t Location.loc

val ctyp_long_id_prefix : ctyp -> Longident.t

val ctyp_long_id : ctyp -> bool * Longident.t Location.loc

val predef_option : loc -> ctyp

val ctyp : ctyp -> Parsetree.core_type

val row_field :  row_field -> Parsetree.row_field list -> Parsetree.row_field list

val meth_list :
    name_ctyp ->
      Parsetree.core_field_type list -> Parsetree.core_field_type list

val package_type_constraints :
  constr ->
    (Longident.t Asttypes.loc * Parsetree.core_type) list ->
      (Longident.t Asttypes.loc * Parsetree.core_type) list

val package_type : mtyp -> Parsetree.package_type

val mkprivate' : bool -> Asttypes.private_flag

val mkprivate : flag -> Asttypes.private_flag

val mktrecord :
  name_ctyp ->
  string Location.loc * Asttypes.mutable_flag * Parsetree.core_type *  loc

val mkvariant :
  or_ctyp ->
  string Location.loc * Parsetree.core_type list *
  Parsetree.core_type option * loc


val mkvalue_desc :
  Location.t -> ctyp -> strings list -> Parsetree.value_description

val mkmutable : flag -> Asttypes.mutable_flag

val paolab : string -> pat -> string



val optional_type_parameters :
  ctyp ->
  (string Asttypes.loc option * (bool * bool)) list
      
val class_parameters :
  type_parameters -> (string Asttypes.loc * (bool * bool)) list
      
val type_parameters_and_type_name :
  ctyp ->
  Longident.t Asttypes.loc *
  (string Asttypes.loc option * (bool * bool)) list

      
val pat_fa :  pat list -> pat -> pat * pat list
      
val deep_mkrangepat : loc -> char -> char -> Parsetree.pattern

val mkrangepat : loc -> char -> char -> Parsetree.pattern

val pat : pat -> Parsetree.pattern


val flag :  loc -> flag -> Asttypes.override_flag

(** {[
  exp (`Id (_loc, ( (`Dot (_loc, `Uid (_loc, "U"), `Lid(_loc,"g"))) )));;
  - : Parsetree.expession =
  {Parsetree.pexp_desc =
  Parsetree.Pexp_ident
  {Asttypes.txt = Longident.Ldot (Longident.Lident "U", "g"); loc = };
  pexp_loc = }

  exp {:exp| $(uid:"A").b |} ; ;       
  - : Parsetree.expession =
  {Parsetree.pexp_desc =
  Parsetree.Pexp_ident
  {Asttypes.txt = Longident.Ldot (Longident.Lident "A", "b"); loc = };
  pexp_loc = }
  Ast2pt.exp {:exp| $(uid:"").b |} ; 
  - : Parsetree.expession =
  {Parsetree.pexp_desc =
  Parsetree.Pexp_ident
  {Asttypes.txt = Longident.Ldot (Longident.Lident "", "b"); loc = };
  pexp_loc = }
  ]}
 *)
val exp : exp -> Parsetree.expression

val label_exp : exp -> Asttypes.label * Parsetree.expression

val bind :
  bind ->
  (Parsetree.pattern * Parsetree.expression) list ->
  (Parsetree.pattern * Parsetree.expression) list
      
val case :
  case ->
  (Parsetree.pattern * Parsetree.expression) list

val mklabexp :
  rec_exp ->
  (Longident.t Asttypes.loc * Parsetree.expression) list


(** Example: {[
   (of_stru {:stru|type u = int and v  = [A of u and b ] |})
   ||> mktype_decl |> AstPrint.default#type_def_list f;
   type u = int 
   and v =  
   | A of u* b]}
 *)    
      
val mktype_decl :
  typedecl ->
  (string Asttypes.loc * Parsetree.type_declaration) list

val mtyp : mtyp -> Parsetree.module_type

val module_sig_bind :
  mbind ->
  (string Asttypes.loc * Parsetree.module_type) list ->
  (string Asttypes.loc * Parsetree.module_type) list
      
val module_str_bind :
  mbind ->
  (string Asttypes.loc * Parsetree.module_type * Parsetree.module_expr) list ->
  (string Asttypes.loc * Parsetree.module_type * Parsetree.module_expr) list
      
val mexp : mexp -> Parsetree.module_expr

val cltyp : cltyp -> Parsetree.class_type

val class_info_clexp : cldecl -> Parsetree.class_declaration

val class_info_cltyp : cltdecl -> Parsetree.class_description

val clsigi :
  clsigi ->
  Parsetree.class_type_field list -> Parsetree.class_type_field list

val clexp : clexp -> Parsetree.class_expr

val clfield :
  clfield ->
  Parsetree.class_field list -> Parsetree.class_field list

val sigi : sigi -> Parsetree.signature_item list

val stru : stru -> Parsetree.structure_item list

val directive : exp -> Parsetree.directive_argument

(** translate Fan's phrase into parsetree, notice that
   some  [directives] are passed to parsetree if not handled *)    
val phrase : stru -> Parsetree.toplevel_phrase
    
val pp : formatter -> ('a, formatter, unit) format -> 'a

val print_exp : formatter -> exp -> unit
val to_string_exp : exp -> string
    
val print_pat : formatter -> pat -> unit

val print_stru : formatter -> stru -> unit

val print_ctyp : formatter -> ctyp -> unit
  
