val ocaml_standard_library : string

val version : string
val program_name : string ref
val unsafe : bool ref
val verbose : bool ref
val antiquotations : bool ref
val quotations : bool ref
val inter_phrases : string option ref
val camlp4_ast_impl_magic_number : string
val camlp4_ast_intf_magic_number : string
val ocaml_ast_intf_magic_number : string
val ocaml_ast_impl_magic_number : string
val current_input_file : string ref
val bug_main_address : string
val fan_debug : bool ref
val conversion_table : (string, string) Hashtbl.t
val gram_warning_verbose : bool ref
val compilation_unit : string option ref