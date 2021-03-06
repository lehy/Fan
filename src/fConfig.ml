


let ocaml_standard_library = Oconfig.standard_library;;


let version = Sys.ocaml_version;;
let unsafe             = ref false;;
let verbose            = ref false;;
let antiquotations     = ref false;;
let inter_phrases: string option ref
    = ref None;;
let impl_magic_number = "FAN2013M002";;
let intf_magic_number = "FAN2013N002";;

let ocaml_ast_intf_magic_number = Oconfig.ast_intf_magic_number;;
let ocaml_ast_impl_magic_number = Oconfig.ast_impl_magic_number;;

let current_input_file = ref "";;

(* new config *)
let bug_main_address = "hongboz@seas.upenn.edu";;

let fan_debug = ref false;;
let conversion_table : (string, string) Hashtbl.t = Hashtbl.create 50


let gram_warning_verbose = ref true

let compilation_unit = ref None


let include_dirs = ref []

let dynload_dirs = ref []

let fan_standard_library =
  try Sys.getenv "FAN_DIR"
  with Not_found -> 
    Filename.concat ocaml_standard_library "fan"

      
let fan_plugins_library =
  try
    Sys.getenv "FAN_LIB_DIR"
  with Not_found ->
    Filename.concat ocaml_standard_library "fanplugin"
      
(* when you do the iteration, you should do it in reverse order *)  
(* let current_filters:  ref (list (plugin_name * plugin)) = ref [];; *)


