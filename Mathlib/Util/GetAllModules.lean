/-
Copyright (c) 2024 Damiano Testa. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro, Kim Morrison, Damiano Testa
-/

import Lean.Util.Path
import Lake.CLI.Main


/-!
# Utility functions for finding all `.lean` files or modules in a project.

TODO:
`getLeanLibs` contains a hard-coded choice of which dependencies should be built and which ones
should not.  Could this be made more structural and robust, possibly with extra `Lake` support?

-/

open Lean System.FilePath

/-- `getAllFiles git ml` takes all `.lean` files in the directory `ml`
(recursing into sub-directories) and returns the `Array` of `String`s
```
#[file₁, ..., fileₙ]
```
of all their file names.

The input `git` is a `Bool`ean flag:
* `true` means that the command uses `git ls-files` to find the relevant files;
* `false` means that the command recursively scans all dirs searching for `.lean` files.
-/
def getAllFiles (git : Bool) (ml : String) : IO (Array System.FilePath) := do
  let ml.lean := addExtension ⟨ml⟩ "lean"  -- for example, `Mathlib.lean`
  let allModules : Array System.FilePath ← (do
    if git then
      let mlDir := ml.push pathSeparator   -- for example, `Mathlib/`
      let allLean ← IO.Process.run { cmd := "git", args := #["ls-files", mlDir ++ "*.lean"] }
      return (((allLean.dropRightWhile (· == '\n')).splitOn "\n").map (⟨·⟩)).toArray
    else do
      let all ← walkDir ml
      return all.filter (·.extension == some "lean"))
  let files := (allModules.erase ml.lean).qsort (·.toString < ·.toString)
  let existingFiles ← files.mapM fun f => do
    -- this check is helpful in case the `git` option is on and a local file has been removed
    if ← pathExists f then
      return f
    else return ""
  return existingFiles.filter (· != "")

/-- Like `getAllFiles`, but return an array of *module* names instead,
i.e. names of the form `"Mathlib.Algebra.Algebra.Basic"`. -/
def getAllModules (git : Bool) (ml : String) : IO (Array String) := do
  let files ← getAllFiles git ml
  return ← files.mapM fun f => do
     return (← moduleNameOfFileName f none).toString

open Lake in
/-- `getLeanLibs` returns the names (as an `Array` of `String`s) of all the libraries
on which the current project depends.
If the current project is `mathlib`, then it excludes the libraries `Cache` and `LongestPole` and
it includes `Mathlib/Tactic`. -/
def getLeanLibs : IO (Array String) := do
  let (elanInstall?, leanInstall?, lakeInstall?) ← findInstall?
  let config ← MonadError.runEIO <| mkLoadConfig { elanInstall?, leanInstall?, lakeInstall? }
  let ws ← MonadError.runEIO (MainM.runLogIO (loadWorkspace config)).toEIO
  let package := ws.root
  let libs := (package.leanLibs.map (·.name)).map (·.toString)
  return if package.name == `mathlib then
    libs.erase "Cache" |>.erase "LongestPole" |>.push ("Mathlib".push pathSeparator ++ "Tactic")
  else
    libs
