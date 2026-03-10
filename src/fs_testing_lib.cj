// libFs: list of UnitFns from std.fs for PBT. Shared state (Box<Option<File>>) for close-current-file.
package cangjie_experiments

import std.collection.*
import std.fs.*
import stdx.effect.*
import cangjie_experiments.define.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*
import cangjie_experiments.input_print.*

// Symlink runners only on non-Windows (symlink APIs may require privileges or differ on Windows).
@When[os != "Windows"]
func getSymlinkRunners(fg: FsContext): ArrayList<UnitFn> {
    ArrayList([
        @RunRandomly([link in fg.randFreshPath, to in fg.randExistingPath], fg.symbolicLinkCreate),
        @RunRandomly([path in fg.randExistingSymlinkPath], fg.symbolicLinkReadFrom),
    ])
}
@When[os == "Windows"]
func getSymlinkRunners(fg: FsContext): ArrayList<UnitFn> {
    ArrayList()
}

// Builds libFs: path-based std.fs UnitFns plus close-current-file. Uses tmp under repo root.
// TODO: copyWithoutOverwrite, renameWithoutOverwrite - not yet registered.
public func getLibFs(fg : FsContext): ArrayList<UnitFn> {
    let lib = ArrayList([
        @RunRandomly([path in fg.randPath], fg.exists),
        @RunRandomly([path in fg.randExistingPath], fg.remove),
        @RunRandomly([path in fg.randPath], fg.removeIfExists),
        @RunRandomly([path in fg.randFreshPath], fg.directoryCreateRecursive),
        @RunRandomly([path in fg.randFreshPath], fg.fileCreate),
        @RunRandomly([path in fg.randExistingFilePath], fg.fileReadFrom),
        @RunRandomly([path in fg.randExistingFilePath, content in randSmallBytes()], fg.fileWriteTo),
        @RunRandomly([path in fg.randExistingFilePath, content in randSmallBytes()], fg.fileAppendTo),
        @RunRandomly([path in fg.randExistingPath], fg.canonicalize),
        @RunRandomly([sourcePath in fg.randExistingPath, to in fg.randFreshPath], fg.copyWithOverwrite),
        @RunRandomly([sourcePath in fg.randExistingPath, to in fg.randFreshPath], fg.renameWithOverwrite),
        @RunRandomly([path in fg.randFreshPathWithExistingParent], fg.directoryCreateNonRecursive),
        @RunRandomly([directoryPath in fg.randExistingDirPath], fg.directoryCreateTemp),
        @RunRandomly([path in fg.randExistingDirPath], fg.directoryReadFrom),
        @RunRandomly([path in fg.randExistingDirPath], fg.directoryWalk),
        @RunRandomly([directoryPath in fg.randExistingDirPath], fg.fileCreateTemp),
        @RunRandomly([link in fg.randFreshPath, to in fg.randExistingFilePath], fg.hardLinkCreate),
    ])
    lib.add(all: getSymlinkRunners(fg))
    return lib
}
