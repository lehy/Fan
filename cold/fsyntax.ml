open FAst

type warning = FLoc.t -> string -> unit 

let default_warning loc txt =
  Format.eprintf "<W> %a: %s@." FLoc.print loc txt

let current_warning = ref default_warning

let print_warning loc txt = current_warning.contents loc txt

let a_ident = Fgram.mk "a_ident"

let aident = Fgram.mk "aident"

let amp_ctyp = Fgram.mk "amp_ctyp"

let and_ctyp = Fgram.mk "and_ctyp"

let case = Fgram.mk "case"

let case0 = Fgram.mk "case0"

let bind = Fgram.mk "bind"

let class_declaration = Fgram.mk "class_declaration"

let class_description = Fgram.mk "class_description"

let clexp = Fgram.mk "clexp"

let class_fun_bind = Fgram.mk "class_fun_bind"

let class_fun_def = Fgram.mk "class_fun_def"

let class_info_for_cltyp = Fgram.mk "class_info_for_cltyp"

let class_longident = Fgram.mk "class_longident"

let class_name_and_param = Fgram.mk "class_name_and_param"

let clsigi = Fgram.mk "clsigi"

let class_signature = Fgram.mk "class_signature"

let clfield = Fgram.mk "clfield"

let class_structure = Fgram.mk "class_structure"

let cltyp = Fgram.mk "cltyp"

let cltyp_declaration = Fgram.mk "cltyp_declaration"

let cltyp_longident = Fgram.mk "cltyp_longident"

let cltyp_plus = Fgram.mk "cltyp_plus"

let com_ctyp = Fgram.mk "com_ctyp"

let comma_ctyp = Fgram.mk "comma_ctyp"

let comma_exp = Fgram.mk "comma_exp"

let comma_ipat = Fgram.mk "comma_ipat"

let comma_pat = Fgram.mk "comma_pat"

let comma_type_parameter = Fgram.mk "comma_type_parameter"

let constrain = Fgram.mk "constrain"

let constructor_arg_list = Fgram.mk "constructor_arg_list"

let constructor_declaration = Fgram.mk "constructor_declaration"

let constructor_declarations = Fgram.mk "constructor_declarations"

let ctyp = Fgram.mk "ctyp"

let cvalue_bind = Fgram.mk "cvalue_bind"

let flag = Fgram.mk "flag"

let direction_flag_quot = Fgram.mk "direction_flag_quot"

let eq_exp = Fgram.mk "eq_exp"

let exp = Fgram.mk "exp"

let exp_eoi = Fgram.mk "exp_eoi"

let field_exp = Fgram.mk "field_exp"

let field_exp_list = Fgram.mk "field_exp_list"

let fun_bind = Fgram.mk "fun_bind"

let fun_def = Fgram.mk "fun_def"

let ident = Fgram.mk "ident"

let implem = Fgram.mk "implem"

let interf = Fgram.mk "interf"

let ipat = Fgram.mk "ipat"

let ipat_tcon = Fgram.mk "ipat_tcon"

let pat_tcon = Fgram.mk "pat_tcon"

let label_declaration = Fgram.mk "label_declaration"

let label_declaration_list = Fgram.mk "label_declaration_list"

let label_exp = Fgram.mk "label_exp"

let label_exp_list = Fgram.mk "label_exp_list"

let label_pat_list = Fgram.mk "label_pat_list"

let label_pat = Fgram.mk "label_pat"

let label_longident = Fgram.mk "label_longident"

let let_bind = Fgram.mk "let_bind"

let meth_list = Fgram.mk "meth_list"

let meth_decl = Fgram.mk "meth_decl"

let mbind = Fgram.mk "mbind"

let mbind = Fgram.mk "mbind"

let mbind0 = Fgram.mk "mbind0"

let mexp = Fgram.mk "mexp"

let module_longident = Fgram.mk "module_longident"

let module_longident_with_app = Fgram.mk "module_longident_with_app"

let module_rec_declaration = Fgram.mk "module_rec_declaration"

let mtyp = Fgram.mk "mtyp"

let name_tags = Fgram.mk "name_tags"

let opt_class_self_pat = Fgram.mk "opt_class_self_pat"

let opt_class_self_type = Fgram.mk "opt_class_self_type"

let opt_comma_ctyp = Fgram.mk "opt_comma_ctyp"

let opt_dot_dot = Fgram.mk "opt_dot_dot"

let row_var_flag_quot = Fgram.mk "row_var_flag_quot"

let opt_exp = Fgram.mk "opt_exp"

let opt_meth_list = Fgram.mk "opt_meth_list"

let opt_mutable = Fgram.mk "opt_mutable"

let mutable_flag_quot = Fgram.mk "mutable_flag_quot"

let opt_polyt = Fgram.mk "opt_polyt"

let opt_private = Fgram.mk "opt_private"

let private_flag_quot = Fgram.mk "private_flag_quot"

let opt_rec = Fgram.mk "opt_rec"

let rec_flag_quot = Fgram.mk "rec_flag_quot"

let opt_virtual = Fgram.mk "opt_virtual"

let virtual_flag_quot = Fgram.mk "virtual_flag_quot"

let opt_override = Fgram.mk "opt_override"

let override_flag_quot = Fgram.mk "override_flag_quot"

let pat = Fgram.mk "pat"

let pat_as_pat_opt = Fgram.mk "pat_as_pat_opt"

let pat_eoi = Fgram.mk "pat_eoi"

let row_field = Fgram.mk "row_field"

let sem_exp = Fgram.mk "sem_exp"

let sem_exp_for_list = Fgram.mk "sem_exp_for_list"

let sem_pat = Fgram.mk "sem_pat"

let sem_pat_for_list = Fgram.mk "sem_pat_for_list"

let semi = Fgram.mk "semi"

let sequence = Fgram.mk "sequence"

let sigi = Fgram.mk "sigi"

let sigis = Fgram.mk "sigis"

let star_ctyp = Fgram.mk "star_ctyp"

let stru = Fgram.mk "stru"

let strus = Fgram.mk "strus"

let top_phrase = Fgram.mk "top_phrase"

let type_declaration = Fgram.mk "type_declaration"

let type_ident_and_parameters = Fgram.mk "type_ident_and_parameters"

let type_longident = Fgram.mk "type_longident"

let type_longident_and_parameters = Fgram.mk "type_longident_and_parameters"

let type_parameter = Fgram.mk "type_parameter"

let type_parameters = Fgram.mk "type_parameters"

let typevars = Fgram.mk "typevars"

let val_longident = Fgram.mk "val_longident"

let constr = Fgram.mk "constr"

let exp_quot = Fgram.mk "exp_quot"

let pat_quot = Fgram.mk "pat_quot"

let ctyp_quot = Fgram.mk "ctyp_quot"

let stru_quot = Fgram.mk "stru_quot"

let sigi_quot = Fgram.mk "sigi_quot"

let clfield_quot = Fgram.mk "clfield_quot"

let clsigi_quot = Fgram.mk "clsigi_quot"

let mexp_quot = Fgram.mk "mexp_quot"

let mtyp_quot = Fgram.mk "mtyp_quot"

let cltyp_quot = Fgram.mk "cltyp_quot"

let clexp_quot = Fgram.mk "clexp_quot"

let constr_quot = Fgram.mk "constr_quot"

let bind_quot = Fgram.mk "bind_quot"

let rec_exp_quot = Fgram.mk "rec_exp_quot"

let module_declaration = Fgram.mk "module_declaration"

let type_info = Fgram.mk "type_info"

let type_repr = Fgram.mk "type_repr"

let infixop0 = Fgram.mk "or ||"

let infixop1 = Fgram.mk "& &&"

let infixop2 =
  Fgram.mk "infix operator (level 2) (comparison operators, and some others)"

let infixop3 = Fgram.mk "infix operator (level 3) (start with '^', '@')"

let infixop4 = Fgram.mk "infix operator (level 4) (start with '+', '-')"

let infixop5 = Fgram.mk "infix operator (level 5) (start with '*', '/', '%')"

let infixop6 =
  Fgram.mk "infix operator (level 6) (start with \"**\") (right assoc)"

let prefixop = Fgram.mk "prefix operator (start with '!', '?', '~')"

let case_quot = Fgram.mk "quotation of case (try/match/function case)"

let module_longident_dot_lparen = Fgram.mk "module_longident_dot_lparen"

let sequence' = Fgram.mk "sequence'"

let fun_def = Fgram.mk "fun_def"

let mbind_quot = Fgram.mk "mbind_quot"

let ident_quot = Fgram.mk "ident_quot"

let string_list = Fgram.mk "string_list"

let method_opt_override = Fgram.mk "method_opt_override"

let value_val_opt_override = Fgram.mk "value_val_opt_override"

let unquoted_typevars = Fgram.mk "unquoted_typevars"

let lang = Fgram.mk "lang"

let with_exp_lang = Fgram.mk "with_exp_lang"

let with_stru_lang = Fgram.mk "with_stru_lang"

let dot_lstrings = Fgram.mk "dot_lstrings"

let a_string = Fgram.mk "a_string"

let a_lident = Fgram.mk "a_lident"

let a_uident = Fgram.mk "a_uident"

let luident = Fgram.mk "luident"

let uident = Fgram.mk "uident"

let vid = Fgram.mk "vid"

let astr = Fgram.mk "astr"

let antiquot_exp = Fgram.eoi_entry exp

let antiquot_pat = Fgram.eoi_entry pat

let antiquot_ident = Fgram.eoi_entry ident

let parse_exp loc str = Fgram.parse_string antiquot_exp ~loc str

let parse_pat loc str = Fgram.parse_string antiquot_pat ~loc str

let parse_ident loc str = Fgram.parse_string antiquot_ident ~loc str

let anti_filter = Ant.antiquot_expander ~parse_exp ~parse_pat

let exp_filter (x : ep) = anti_filter#exp (x :>exp)

let pat_filter (x : ep) = anti_filter#pat (x :>pat)

let anti_filter_n = AntN.antiquot_expander ~parse_exp ~parse_pat

let exp_filter_n (x : ep) = anti_filter_n#exp (x :>exp)

let pat_filter_n (x : ep) = anti_filter_n#pat (x :>pat)