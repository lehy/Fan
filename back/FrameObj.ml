

open AstLib
open Ast
open Format
open LibUtil
open Basic
open FSig
open Exp

(* preserved keywords for the generator *)
let preserve =  ["self"; "self_type"; "unit"; "result"]

let check names =
  List.iter (fun name ->
    if List.mem name preserve  then begin 
      eprintf "%s is not a valid name\n" name;
      eprintf "preserved keywords:\n";
      List.iter (fun s -> eprintf "%s\n" s) preserve;
      exit 2
    end
    else check_valid name) names


let mapi_exp ?(arity=1) ?(names=[])
    ~f:(f:(ctyp->exp))
    (i:int) (ty : ctyp)  :
    FSig.ty_info =
  let name_exp = f ty in 
  let base = name_exp  +> names in
  (* FIXME as a tuple it is useful when arity> 1??? *)
  let id_eps = List.init arity (fun index  -> xid ~off:index i ) in 
  let ep0 = List.hd id_eps in
  let id_ep = tuple_com  id_eps  in
  let exp = appl_of_list (base:: (id_eps:>exp list))  in
  {name_exp;
   info_exp=exp;
   id_ep;
   id_eps;
   ep0;
   ty
 }
  
class synth
    ~arity:(arity:int)
    ~names:(names:string list)
    ~left_type_id:(left_type_id:basic_id_transform)
    ~right_type_id:(right_type_id:full_id_transform)
    ~right_type_variable:(right_type_variable:rhs_basic_id_transform)
    ~cons_transform:(cons_transform:string->string)
    ~default:(default: (vrn * int) -> Ast.case option)
    ~cxt:(cxt:(string,unit)Hashtbl.t)
    = object(self:'self)
      method mk_tuple : ty_info list -> exp = assert false
      method mk_variant : string -> ty_info list -> exp = assert false
      (* called self#tuple internal *)    
      method transform (ty : ctyp) : exp =
        let open Transform in
        let right_trans = transform right_type_id in
        let left_trans = basic_transform left_type_id in 
        let tyvar = right_transform right_type_variable  in 
        let rec aux = with {pat:ctyp;exp} function
          | `Lid(_loc,id) -> 
              if Hashset.mem cxt id then {| $(lid:left_trans id) |}
              else
                right_trans (`Lid(_loc,id))
          | (#ident' as id) ->
              right_trans (Id.to_vid id )
          | `App(_loc,t1,t2) ->
              {| $(aux t1) $(aux t2) |}
          | `Quote (_loc,_,`Lid(_,s)) ->   tyvar s
          | `Arrow(_loc,t1,t2) ->
              aux {:ctyp| ($t1,$t2) arrow |} (* arrow is a keyword now*)
          | `Par _  as ty ->
              self#tuple ty 
          | (ty:ctyp) ->
              FanLoc.errorf (loc_of ty) "normal_simple_exp_of_ctyp : %s"
                (Objs.dump_ctyp ty) in aux ty
      (* called self#transform internal *)    
      method tuple (ty:ctyp) =
          match ty with
          | `Par (_loc,t)  -> 
              let ls = list_of_star t [] in
              let len = List.length ls in
              let pat = (EP.mk_tuple ~arity ~number:len :> pat) in
              let tys =
                self#mk_tuple (List.mapi (mapi_exp ~arity ~names  ~f:self#transform) ls) in
              names <+ currying [ {:case| $pat:pat -> $tys |} ] ~arity
          | _  ->
              let _loc = loc_of ty in
              FanLoc.errorf _loc "tuple_exp_of_ctyp %s" (Objs.dump_ctyp ty)
                
      method or_ctyp (ty:or_ctyp) =
        let f  (cons:string) (tyargs:ctyp list )  : case = 
          let args_length = List.length tyargs in  (* ` is not needed here *)
          let p : pat = (* calling gen_tuple_n*)
            (EP.gen_tuple_n ~cons_transform ~arity  cons args_length :> pat) in
          let mk (cons,tyargs) =
            let exps = List.mapi (mapi_exp ~arity ~names ~f:self#transform) tyargs in
            self#mk_variant cons exps in
          let e = mk (cons,tyargs) in
          let _loc =  p <+>  e in 
          {:case| $pat:p -> $e |} in  begin 
            let info = (Sum, List.length (list_of_or ty [])) in 
            let res :  case list = Ctyp.reduce_data_ctors ty  [] f ~compose:cons  in
            let res =
              let t = (* only under this case we need defaulting  *)
                if List.length res >= 2 && arity >= 2 then
                  match default info with
                  | Some x-> x::res | None -> res 
                        (* [ default info :: res ] *)
                else res in
              List.rev t in 
            currying ~arity res 
          end
          
end
