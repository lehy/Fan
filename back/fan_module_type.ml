(* open Format;
 * open Camlp4.PreCast;
 * open Lib_common;
 * (\* open Fan_camlp4; *\)
 * open Fan_basic;
 * open Fan_sig; *)
<:fan<
lang "module_type";
>>;

<:include_ml<
"open_template.ml";
>>;

(** Utility for Ast.module_type *)


value app  mt1 mt2 =   match (mt1, mt2) with
    [ (<< .$id:i1$. >>, << .$id:i2$. >>) ->
        << .$id: <:ident< .$i1$. .$i2$. >> $. >>
    | _ -> invalid_arg "Fan_module_type app" ];
(**
   This is the place where [IdApp] makes sense
   {[
   app << A >> << B >>;

   MtId  (IdApp  (IdUid  "A") (IdUid  "B"))
   ]}
   Here we need define [module_type_app], since
   {[
     |	IdApp of loc * ident* ident
     |	ExApp of loc * expr * expr
   ]}
   but for module_expr
   {[
     |	MeId of loc * ident
     |	MeApp of loc * module_expr * module_expr
   ]}
   since we require that for module_type_app operation, only
   MeId can be used as app operation.
*)      


value acc mt1 mt2 =
    match (mt1, mt2) with
    [ (<< .$id:i1$. >>, << .$id:i2$. >>) ->
        << .$id:<:ident< .$i1$. . .$i2$. >>$. >>
    | _ -> invalid_arg "Fan_module_type acc"];
(**
   {[
   acc << A >> << B >>;
   MtId  (IdAcc  (IdUid  "A") (IdUid  "B"))
   ]}
 *)      
















