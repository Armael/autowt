open Bos
open Rresult
module AS = Astring.String
module BR = Base.Result

module Let_syntax = struct
  let bind x ~f = Rresult.R.(>>=) x f
  let map x ~f = Rresult.R.(>>|) x f
end

let run_quiet cmd =
  OS.Cmd.(in_null |> run_io cmd |> out_null |> success)

let fetch_remote remote =
  run_quiet Cmd.(v "git" % "fetch" % remote)

let add_remote remote =
  let url = Printf.sprintf "https://github.com/%s/ocaml.git" remote in
  run_quiet Cmd.(v "git" % "remote" % "add" % remote % url)

let main ~username ~branch =
  (* Hackish *)
  let remote = if username = "armael" then "origin" else
      String.lowercase_ascii username
  in
  let%bind cwd = OS.Dir.current () in
  let%bind main_dir = OS.Path.must_exist Fpath.(cwd / "main") in
  let%bind res = OS.Dir.with_current main_dir (fun () ->
    let%bind remotes = OS.Cmd.(run_out Cmd.(v "git" % "remote") |> to_lines) in
    let%bind () =
      if not (List.mem remote remotes) then (
        Printf.eprintf "Adding remote %s...\n%!" remote;
        add_remote remote
      ) else (
        Printf.eprintf "Remote %s already exists.\n%!" remote;
        Ok ()
      )
    in
    Printf.eprintf "Fetching remote %s...\n%!" remote;
    let%bind () = fetch_remote remote in
    let%bind all_branches_raw =
      OS.Cmd.(run_out Cmd.(v "git" % "branch" % "-r") |> to_lines)
    in
    let%bind all_branches = List.map (fun s ->
      let s = AS.trim s |> String.split_on_char ' ' |> List.hd in
      match Pat.(query (v "$(remote)/$(branch)") s) with
      | None -> R.error_msgf "Could not parse the result of git branch -r: \'%s\'" s
      | Some d -> Ok (AS.Map.get "remote" d, AS.Map.get "branch" d)
    ) all_branches_raw |> BR.all
    in
    let%bind branchref =
      if List.mem (remote, branch) all_branches then (
        Printf.eprintf "Found branch %s/%s.\n%!" remote branch;
        Ok (remote ^ "/" ^ branch)
      ) else if remote = "origin" then (
        (* Create a new local branch based on trunk *)
        Printf.eprintf "Creating local branch %s on top of trunk...\n%!" branch;
        let%bind () = run_quiet Cmd.(v "git" % "fetch" % "upstream") in
        let%bind () = run_quiet Cmd.(v "git" % "branch" % branch % "upstream/trunk") in
        Ok branch
      ) else
        R.error_msgf "Branch %s/%s does not exist" remote branch
    in
    let worktree_dir_name =
      if remote = "origin" then branch else remote ^ "-" ^ branch in
    let worktree_dir = Fpath.(cwd / worktree_dir_name) in
    let wds = Fpath.(to_string worktree_dir) in
    let%bind () =
      if%bind OS.Path.exists worktree_dir then (
        Printf.eprintf "Worktree directory %s already exists\n%!" wds;
        Ok ()
      ) else (
        Printf.eprintf "Adding worktree directory %s for branch %s\n%!"
          wds branchref;
        run_quiet
          Cmd.(v "git" % "worktree" % "add" % p worktree_dir % branchref)
      )
    in
    Ok wds
  ) ()
  in res

let () =
  match Sys.argv |> Array.to_list |> List.tl with
  | [ username; branch ] ->
    begin match main ~username ~branch with
      | Ok s -> print_endline s
      | Error (`Msg msg) -> Printf.eprintf "Error: %s\n%!" msg; exit 1
    end
  | _ -> Printf.eprintf "usage: ./autowt username branch"
