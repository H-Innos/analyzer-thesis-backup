open Batteries
open Jsonrpc
open GoblintCil

type t = {
  mutable file: Cil.file option;
  mutable max_ids: MaxIdUtil.max_ids;
  input: IO.input;
  output: unit IO.output;
}

module type Request = sig
  val name: string

  type params
  type response

  val params_of_yojson: Yojson.Safe.t -> (params, string) result
  val response_to_yojson: response -> Yojson.Safe.t

  val process: params -> t -> response
end

module Registry = struct
  type t = (string, (module Request)) Hashtbl.t
  let make () : t = Hashtbl.create 32
  let register (reg: t) (module R : Request) = Hashtbl.add reg R.name (module R)
end

let registry = Registry.make ()

module ParamParser (R : Request) = struct
  let parse params =
    let maybe_params =
      params
      |> Option.map_default Structured.yojson_of_t `Null
      |> R.params_of_yojson
    in
    match maybe_params with
    | Ok params -> Ok params
    | Error err ->
      (* This is a hack to handle cases where R.params is a primitive type like int or string. *)
      match params with
      | Some `List [param] -> R.params_of_yojson param |> Result.map_error (fun _ -> err)
      | _ -> Error err
end

module Function = struct
  type t = {
    funName: string;
    location: CilType.Location.t;
  } [@@deriving eq, ord, hash, yojson]

  let filterFunctions = function
    | Cil.GFun (fd, loc) -> Some {funName = fd.svar.vname; location = loc}
    | _ -> None

  let getFunctionsList files = List.filter_map filterFunctions files
end

let handle_request (serv: t) (request: Request.t): Response.t =
  match Hashtbl.find_option registry request.method_ with
  | Some (module R) ->
    let module Parser = ParamParser (R) in
    begin match Parser.parse request.params with
      | Ok params ->
        begin try
            Maingoblint.reset_stats ();
            let r =
              R.process params serv
              |> R.response_to_yojson
              |> Response.ok request.id
            in
            Maingoblint.do_stats ();
            r
          with Response.Error.E error ->
            Response.error request.id error
        end
      | Error message ->
        Response.(Error.make ~code:InvalidParams ~message () |> error request.id)
    end
  | _ ->
    Response.(Error.make ~code:MethodNotFound ~message:request.method_ () |> error request.id)

let handle_packet (serv: t) (packet: Packet.t) =
  let response_packet: Packet.t option = match packet with
    | Request request -> Some (Response (handle_request serv request))
    | Batch_call subpackets ->
      let responses = List.filter_map (function
          | `Request request -> Some (handle_request serv request)
          | _ -> None (* ignore others for now *)
        ) subpackets in
      Some (Batch_response responses)
    | _ -> None (* ignore others for now *)
  in
  match response_packet with
  | Some response_packet ->
    Packet.yojson_of_t response_packet |> Yojson.Safe.to_string |> IO.write_line serv.output;
    IO.flush serv.output
  | None -> ()

let serve serv =
  serv.input
  |> Lexing.from_channel
  |> Yojson.Safe.seq_from_lexbuf (Yojson.init_lexer ())
  |> Seq.map Packet.t_of_yojson
  |> Seq.iter (handle_packet serv)

let make ?(input=stdin) ?(output=stdout) file : t =
  let max_ids =
    match file with
    | Some file -> MaxIdUtil.get_file_max_ids file
    | None -> MaxIdUtil.get_file_max_ids Cil.dummyFile (* TODO: avoid this altogether *)
  in
  {
    file;
    max_ids;
    input;
    output
  }

let bind () =
  let mode = GobConfig.get_string "server.mode" in
  if mode = "stdio" then None, None else (
    let path = GobConfig.get_string "server.unix-socket" in
    if Sys.file_exists path then
      Sys.remove path;
    let socket = Unix.socket PF_UNIX SOCK_STREAM 0 in
    Unix.bind socket (ADDR_UNIX path);
    Unix.listen socket 1;
    let conn, _ = Unix.accept socket in
    Unix.close socket;
    Sys.remove path;
    Some (Unix.input_of_descr conn), Some (Unix.output_of_descr conn))

let start file =
  let input, output = bind () in
  GobConfig.set_bool "incremental.save" true;
  Maingoblint.do_stats (); (* print pre-server stats just in case *)
  serve (make file ?input ?output)

let reparse (s: t) =
  if GobConfig.get_bool "server.reparse" then (
    GoblintDir.init ();
    let file = Fun.protect ~finally:GoblintDir.finalize Maingoblint.preprocess_parse_merge in
    begin match s.file with
      | None ->
        let max_ids = MaxIdUtil.get_file_max_ids file in
        s.max_ids <- max_ids
      | Some _ ->
        ()
    end;
    (file, true)
  )
  else
    (Option.get s.file, false)

(* Only called when the file has not been reparsed, so we can skip the expensive CFG comparison. *)
let virtual_changes file =
  let eq (glob: Cil.global) _ _ _ = match glob with
    | GFun (fdec, _) when CompareCIL.should_reanalyze fdec -> CompareCIL.ForceReanalyze fdec, None
    | _ -> Unchanged, None
  in
  CompareCIL.compareCilFiles ~eq file file

let increment_data (s: t) file reparsed = match Serialize.Cache.get_opt_data SolverData with
  | Some solver_data when reparsed ->
    let s_file = Option.get s.file in
    let changes = CompareCIL.compareCilFiles s_file file in
    s.max_ids <- UpdateCil.update_ids s_file s.max_ids file changes;
    (* TODO: get globals for restarting from config *)
    Some { server = true; Analyses.changes; solver_data; restarting = [] }, false
  | Some solver_data ->
    let changes = virtual_changes file in
    (* TODO: get globals for restarting from config *)
    Some { server = true; Analyses.changes; solver_data; restarting = [] }, false
  | _ -> None, true

let analyze ?(reset=false) (s: t) =
  Messages.Table.(MH.clear messages_table);
  Messages.Table.messages_list := [];
  let file, reparsed = reparse s in
  if reset then (
    let max_ids = MaxIdUtil.get_file_max_ids file in
    s.max_ids <- max_ids;
    Serialize.Cache.reset_data SolverData;
    Serialize.Cache.reset_data AnalysisData);
  let increment_data, fresh = increment_data s file reparsed in
  Cilfacade.reset_lazy ();
  WideningThresholds.reset_lazy ();
  IntDomain.reset_lazy ();
  ApronDomain.reset_lazy ();
  AutoTune.reset_lazy ();
  Access.reset ();
  s.file <- Some file;
  GobConfig.set_bool "incremental.load" (not fresh);
  Fun.protect ~finally:(fun () ->
      GobConfig.set_bool "incremental.load" true
    ) (fun () ->
      Maingoblint.do_analyze increment_data (Option.get s.file)
    )

let () =
  let register = Registry.register registry in

  register (module struct
    let name = "analyze"
    type params = { reset: bool [@default false] } [@@deriving of_yojson]
    (* TODO: Return analysis results as JSON. Useful for GobPie. *)
    type status = Success | VerifyError | Aborted [@@deriving to_yojson]
    type response = { status: status } [@@deriving to_yojson]
    (* TODO: Add options to control the analysis precision/context for specific functions. *)
    (* TODO: Add option to mark functions as modified. *)
    let process { reset } serve =
      try
        analyze serve ~reset;
        {status = if !Goblintutil.verified = Some false then VerifyError else Success}
      with Sys.Break ->
        {status = Aborted}
  end);

  register (module struct
    let name = "config"
    type params = string * Yojson.Safe.t [@@deriving of_yojson]
    type response = unit [@@deriving to_yojson]
    (* TODO: Make it possible to change the non-optional parameters. (i.e., the set of input files) *)
    (* TODO: Check options for compatibility with the incremental analysis. *)
    let process (conf, json) _ =
      try
        GobConfig.set_auto conf (Yojson.Safe.to_string json);
        Maingoblint.handle_options ();
      with exn -> (* TODO: Be more specific in what we catch. *)
        Response.Error.(raise (of_exn exn))
  end);

  register (module struct
    let name = "reset_config"
    type params = unit [@@deriving of_yojson]
    type response = unit [@@deriving to_yojson]
    let process () _ =
      try
        GobConfig.json_conf := Options.defaults;
        Maingoblint.parse_arguments ();
      with exn -> (* TODO: Be more specific in what we catch. *)
        Response.Error.(raise (of_exn exn))
  end);

  register (module struct
    let name = "merge_config"
    type params = Yojson.Safe.t [@@deriving of_yojson]
    type response = unit [@@deriving to_yojson]
    let process json _ =
      try
        GobConfig.merge json;
        Maingoblint.handle_options ();
      with exn -> (* TODO: Be more specific in what we catch. *)
        Response.Error.(raise (of_exn exn))
  end);

  register (module struct
    let name = "read_config"
    type params = { fname: string } [@@deriving of_yojson]
    type response = unit [@@deriving to_yojson]
    let process { fname } _ =
      try
        GobConfig.merge_file (Fpath.v fname);
        Maingoblint.handle_options ();
      with exn -> (* TODO: Be more specific in what we catch. *)
        Response.Error.(raise (of_exn exn))
  end);

  register (module struct
    let name = "messages"
    type params = unit [@@deriving of_yojson]
    type response = Messages.Message.t list [@@deriving to_yojson]
    let process () _ = Messages.Table.to_list ()
  end);

  register (module struct
    let name = "files"
    type params = unit [@@deriving of_yojson]
    type response = Yojson.Safe.t [@@deriving to_yojson]
    let process () _ = Preprocessor.dependencies_to_yojson ()
  end);

  register (module struct
    let name = "pre_files"
    type params = unit [@@deriving of_yojson]
    type response = Yojson.Safe.t [@@deriving to_yojson]
    let process () s =
      if GobConfig.get_bool "server.reparse" then (
        GoblintDir.init ();
        Fun.protect ~finally:GoblintDir.finalize (fun () ->
            ignore Maingoblint.(preprocess_files () |> parse_preprocessed)
          )
      );
      Preprocessor.dependencies_to_yojson ()
  end);

  register (module struct
    let name = "functions"
    type params = unit [@@deriving of_yojson]
    type response = Function.t list [@@deriving to_yojson]
    let process () serv = Function.getFunctionsList (Option.get serv.file).globals
  end);

  register (module struct
    let name = "cfg"
    type params = { fname: string }  [@@deriving of_yojson]
    type response = { cfg : string } [@@deriving to_yojson]
    let process { fname } serv =
      let fundec = Cilfacade.find_name_fundec fname in
      let live _ = true in (* TODO: fix this *)
      let cfg = CfgTools.sprint_fundec_html_dot !MyCFG.current_cfg live fundec in
      { cfg }
  end);

  register (module struct
    let name = "node_state"
    type params = { nid: string }  [@@deriving of_yojson]
    type response = Yojson.Safe.t [@@deriving to_yojson]
    let process { nid } serv =
      let f = !Control.current_node_state_json in
      let n = Node.of_id nid in
      let json = f n in
      json
  end);

  register (module struct
    let name = "exp_eval"
    type params = ExpressionEvaluation.query [@@deriving of_yojson]
    type response =
      ((string * CilType.Location.t * string * int) * bool option) list [@@deriving to_yojson]
    let process query serv =
      GobConfig.set_auto "trans.activated[+]" "'expeval'";
      ExpressionEvaluation.gv_query := Some query;
      analyze serv;
      GobConfig.set_auto "trans.activated[-]" "'expeval'";
      !ExpressionEvaluation.gv_results
  end);

  register (module struct
    let name = "ping"
    type params = unit [@@deriving of_yojson]
    type response = [`Pong] [@@deriving to_yojson]
    let process () _ = `Pong
  end)
