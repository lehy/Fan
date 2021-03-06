open FAst

open LibUtil

type key = string 

let inject_exp_tbl: (key,exp) Hashtbl.t = Hashtbl.create 40

let inject_stru_tbl: (key,stru) Hashtbl.t = Hashtbl.create 40

let inject_clfield_tbl: (key,clfield) Hashtbl.t = Hashtbl.create 40

let register_inject_exp (k,f) = Hashtbl.replace inject_exp_tbl k f

let register_inject_stru (k,f) = Hashtbl.replace inject_stru_tbl k f

let register_inject_clfield (k,f) = Hashtbl.replace inject_clfield_tbl k f

let inject_exp = Fgram.mk "inject_exp"

let inject_stru = Fgram.mk "inject_stru"

let inject_clfield = Fgram.mk "inject_clfield"

let _ =
  begin
    Fgram.extend_single (inject_exp : 'inject_exp Fgram.t )
      (None,
        (None, None,
          [([`Stoken
               (((function | `Lid _ -> true | _ -> false)),
                 (`App ((`Vrn "Lid"), `Any)), "`Lid _")],
             ("try Hashtbl.find inject_exp_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n",
               (Fgram.mk_action
                  (fun (__fan_0 : [> FToken.t])  (_loc : FLoc.t)  ->
                     match __fan_0 with
                     | `Lid x ->
                         ((try Hashtbl.find inject_exp_tbl x
                           with
                           | Not_found  ->
                               failwithf "inject.exp %s not found" x) : 
                         'inject_exp )
                     | _ ->
                         failwith
                           "try Hashtbl.find inject_exp_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n"))))]));
    Fgram.extend_single (inject_stru : 'inject_stru Fgram.t )
      (None,
        (None, None,
          [([`Stoken
               (((function | `Lid _ -> true | _ -> false)),
                 (`App ((`Vrn "Lid"), `Any)), "`Lid _")],
             ("try Hashtbl.find inject_stru_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n",
               (Fgram.mk_action
                  (fun (__fan_0 : [> FToken.t])  (_loc : FLoc.t)  ->
                     match __fan_0 with
                     | `Lid x ->
                         ((try Hashtbl.find inject_stru_tbl x
                           with
                           | Not_found  ->
                               failwithf "inject.exp %s not found" x) : 
                         'inject_stru )
                     | _ ->
                         failwith
                           "try Hashtbl.find inject_stru_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n"))))]));
    Fgram.extend_single (inject_clfield : 'inject_clfield Fgram.t )
      (None,
        (None, None,
          [([`Stoken
               (((function | `Lid _ -> true | _ -> false)),
                 (`App ((`Vrn "Lid"), `Any)), "`Lid _")],
             ("try Hashtbl.find inject_clfield_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n",
               (Fgram.mk_action
                  (fun (__fan_0 : [> FToken.t])  (_loc : FLoc.t)  ->
                     match __fan_0 with
                     | `Lid x ->
                         ((try Hashtbl.find inject_clfield_tbl x
                           with
                           | Not_found  ->
                               failwithf "inject.exp %s not found" x) : 
                         'inject_clfield )
                     | _ ->
                         failwith
                           "try Hashtbl.find inject_clfield_tbl x\nwith | Not_found  -> failwithf \"inject.exp %s not found\" x\n"))))]))
  end

let _ =
  let open AstQuotation in
    begin
      of_exp ~name:((`Absolute ["Fan"; "Inject"]), "exp") ~entry:inject_exp;
      of_stru ~name:((`Absolute ["Fan"; "Inject"]), "stru")
        ~entry:inject_stru;
      of_clfield ~name:((`Absolute ["Fan"; "Inject"]), "clfield")
        ~entry:inject_clfield
    end