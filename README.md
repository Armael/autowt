## Autowt

Ad-hoc script to automatically create new git worktrees, either local ones, or
tracking a branch from a github user. At the moment, it is hardcoded for
managing branches and branches in forks of the ocaml compiler.

Usecases:
- I'm starting a new PR: I want to create a new branch on top of trunk and
  create a new git worktree for that branch
  ```shell
  cd $(./autowt armael my-new-branch)
  ```

- I'm reviewing a PR from someone: I want to have a new git worktree with
  their branch in it.
  ```shell
  cd $(./autowt someone their-branch)
  ```

### Assumptions made by the script

The script assumes that it is run from a directory which contains:

- a directory `./$(main_repo)`

  a clone of ocaml from which to run the git commands and create the worktrees.
  `$(main_repo)` corresponds to the value of the `main_repo` parameter set in
  the script. *It is also assumed to contain a remote named "upstream" and
  tracking the upstream repository*.

- other directories, one per worktree, named either:

  + `./some_branch_name` if it has been created from a local branch, or a branch
     from the "origin" remote

  + `./remote-some_branch_name` if it has been created from a remote "remote"
    (not "origin")

### Behaviour

`./autowt.exe username branch`

`username` maps to a remote name. If it is `my_username` (set in the script), it
maps to `origin`. Otherwise, it maps to the username, in lowercase.

If `branch` does not exist *and* the remote (deduced from the username) is
`origin`, instead of failing, the script will create a new local branch of that
name tracking upstream/trunk, and a new worktree for it.
