// withFile and entry point for filesystem PBT. Run from repo root so tmp/ is available.
package cangjie_experiments

import std.collection.*
import std.random.*
import std.fs.*
import cangjie_experiments.define.*
import cangjie_experiments.run_random_config.*
import cangjie_experiments.resumptions.*
import cangjie_experiments.generators.*
import std.io.*

/* 
withFile(path, k): opens file at path, stores in currentFile box, runs k(file), then closes in finally.
Double-close occurs if k performs Switch() and the handler runs the close-current-file UnitFn.
Potential bugs that can be highlighted:
- if path already exists in the environment, then there will be an error when creating the file.
- if the file at `path` is deleted by k(f), then a bug will be triggered when trying to open the file later.
- if the file at `path` has been modified by k(f), then a bug will be triggered when checking the initial contents.
*/
func withFile(path: Path, k: (File) -> Unit): Unit {
    // create a random file with content at `path`
    let content = randSmallBytes(n:10)()

    // Bug triggered here: if the file at `path` already exists, then a bug will be triggered when creating the file.
    if (!exists(path)) {
        File.create(path)
        File.writeTo(path, content)
    } else {
        throw Exception("EXPECTED BUG: withFile bug triggered: file ${path} already exists.")
    }

    // open file for reading and apply k(f) to it a few times
    let f = File(path, OpenMode.Read)
    try {
        k(f)
        k(f)
        k(f)
    } finally {
        f.close()
    }

    // check for existence of file
    // Bug triggered here: if our file happens to be deleted by k(f)
    if (!exists(path)) {
        throw Exception("EXPECTED BUG: withFile bug triggered: file ${path} does not exist.")
    }

    // open the file and appnd to the end
    let fa = File(path, OpenMode.ReadWrite)

    // check the initial contents hasn't been changed
    // Bug triggered here: if our file has been modified by k(f), then the first line will not be equal to content.
    let firstLine = Array<Byte>(1024, repeat: 0)
    fa.read(firstLine)
    for (i in 0..content.size) {
        if (firstLine[i] != content[i]) {
            throw Exception("EXPECTED BUG: withFile bug triggered: first line of file ${path} is not equal to content.")
        }
    }
    fa.write("Final log entry, completed successfully.".toArray())
    fa.close()
}

func dummyTester(path: Path, k: (File) -> Unit) : Unit {
    perform Switch()
    perform Switch()
    perform Switch()
}

// Setup existing environment: create a random file in a given folder.
func randomPathIn(folder: String): () -> Path {{ =>
    let path = Path(folder).join(randShortString(n:2)())
    return path
}}

// Entry: build libFs with shared box, ensure tmp exists, run withFile under executeUntilDone in runInContext.
public func main_fs_testing(): Unit {
    for (i in 0..1000) {
        let fg = FsContext("tmp")
        fg.cleanup()
        withSeed(None) {
            fg.initialiseContext()
            executeUntilDone(
                getLibFs(fg),
                1000, 
                @RunRandomly([path in randomPathIn("tmp"), k in randFunc<File, Unit>], dummyTester))
        }
        fg.cleanup()
        println("********** Iteration ${i+1} completed **********")
    }
}
