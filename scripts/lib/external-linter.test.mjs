import { strict as assert } from "node:assert";
import { test } from "node:test";

import { listSourceFiles } from "./external-linter.mjs";

test("source-file inventory asks git for tracked and unignored files only", () => {
  let invocation;
  const files = listSourceFiles(["scripts/**/*.py"], {
    cwd: "/workspace",
    spawn(command, args, options) {
      invocation = { command, args, options };
      return {
        status: 0,
        stdout: "scripts/release/a.py\nscripts/release/b.py\n"
      };
    }
  });

  assert.deepEqual(files, ["scripts/release/a.py", "scripts/release/b.py"]);
  assert.equal(invocation.command, "git");
  assert.deepEqual(invocation.args, [
    "ls-files",
    "--cached",
    "--others",
    "--exclude-standard",
    "--",
    "scripts/**/*.py"
  ]);
  assert.equal(invocation.options.cwd, "/workspace");
});

test("source-file inventory fails closed when git fails or finds nothing", () => {
  assert.throws(
    () =>
      listSourceFiles(["scripts/**/*.py"], {
        spawn: () => ({ status: 1, stderr: "bad pathspec" })
      }),
    /Unable to inventory source files: bad pathspec/
  );
  assert.throws(
    () =>
      listSourceFiles(["scripts/**/*.py"], {
        spawn: () => ({ status: 0, stdout: "" })
      }),
    /No source files matched/
  );
});
