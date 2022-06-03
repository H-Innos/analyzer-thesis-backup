open Prelude

(* TODO: GoblintDir *)
let incremental_data_file_name = "analysis.data"
let results_dir = "results"

type operation = Save | Load

(** Returns the name of the directory used for loading/saving incremental data *)
let incremental_dirname op = match op with
  | Load -> GobConfig.get_string "incremental.load-dir"
  | Save -> GobConfig.get_string "incremental.save-dir"

let gob_directory op =
  GobFpath.cwd_append (Fpath.v (incremental_dirname op))

let gob_results_dir op =
  Fpath.(gob_directory op / results_dir)

let server () = GobConfig.get_bool "server.enabled"

let marshal obj fileName  =
  let chan = open_out_bin (Fpath.to_string fileName) in
  Marshal.output chan obj;
  close_out chan

let unmarshal fileName =
  if GobConfig.get_bool "dbg.verbose" then
    (* Do NOT replace with Printf because of Gobview: https://github.com/goblint/gobview/issues/10 *)
    print_endline ("Unmarshalling " ^ Fpath.to_string fileName ^ "... If type of content changed, this will result in a segmentation fault!");
  Marshal.input (open_in_bin (Fpath.to_string fileName))

let results_exist () =
  (* If Goblint did not crash irregularly, the existence of the result directory indicates that there are results *)
  let r = gob_results_dir Load in
  let r_str = Fpath.to_string r in
  Sys.file_exists r_str && Sys.is_directory r_str

(** Module to cache the data for incremental analaysis during a run, before it is stored to disk, as well as the server mode *)
module Cache = struct
  type t = {
    solver_data: Obj.t;
    analysis_data: Obj.t;
    version_data: MaxIdUtil.max_ids;
    cil_file: Cil.file;
  }

  type mt = {
    mutable solver_data: Obj.t option;
    mutable analysis_data: Obj.t option;
    mutable version_data: MaxIdUtil.max_ids option;
    mutable cil_file: Cil.file option;
  }

  (** To be used in server mode to temporarly store input_data before it is replaced with new data.
      Needed because a signal might interrupt the copying process. *)
  let backup_data : t option ref = ref None

  (** Data from previous run used as input for incremental analysis *)
  let input_data : t option ref = ref None

  (** Data that generated during the current run is added to tmp_data.
    For server mode, the data that is gathered here, needs to be moved to [input_data] so it can be read in the subsequent run. *)
  let tmp_data = ref {
      solver_data = None;
      analysis_data = None;
      version_data = None;
      cil_file = None;
    }

  (** GADT that may be used to query data from and pass data to the cache. *)
  type _ data_query =
    | SolverData : _ data_query
    | CilFile : Cil.file data_query
    | VersionData : MaxIdUtil.max_ids data_query
    | AnalysisData : _ data_query

  (** Loads data for incremental runs from the appropriate file *)
  let load_data () =
    let p = Fpath.(gob_results_dir Load / incremental_data_file_name) in
    let loaded_data = unmarshal p in
    tmp_data := loaded_data

  (** Stores data for future incremental runs at the appropriate file. *)
  let store_data () =
    GobSys.mkdir_or_exists (gob_directory Save);
    let d = gob_results_dir Save in
    GobSys.mkdir_or_exists d;
    let p = Fpath.(d / incremental_data_file_name) in
    marshal !tmp_data p

  (** Update the some incremental data in the in-memory cache *)
  let update_data: type a. a data_query -> a -> unit = fun q d -> match q with
    | SolverData -> !tmp_data.solver_data <- Some (Obj.repr d)
    | AnalysisData -> !tmp_data.analysis_data <- Some (Obj.repr d)
    | VersionData -> !tmp_data.version_data <- Some d
    | CilFile -> !tmp_data.cil_file <- Some d

  (** Reset some incremental data in the in-memory cache to [None]*)
  let reset_data : type a. a data_query -> unit = function
    | SolverData -> !tmp_data.solver_data <- None
    | AnalysisData -> !tmp_data.analysis_data <- None
    | VersionData -> !tmp_data.version_data <- None
    | CilFile -> !tmp_data.cil_file <- None

  (** Get incremental data from the in-memory cache wrapped in an optional.
      To populate the in-memory cache with data, call [load_data] first. *)
  let get_opt_data : type a. a data_query -> a option = function
    | SolverData -> Option.map Obj.obj !tmp_data.solver_data
    | AnalysisData -> Option.map Obj.obj !tmp_data.analysis_data
    | VersionData -> !tmp_data.version_data
    | CilFile -> !tmp_data.cil_file

  (** Get incremental data from the in-memory cache.
      Same as [get_opt_data], except not yielding an optional and failing when the requested data is not present. *)
  let get_data : type a. a data_query -> a =
    fun a ->
    match get_opt_data a with
    | Some d -> d
    | None -> failwith "Requested data is not loaded."
end
