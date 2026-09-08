import assert from "node:assert/strict";
import { mkdtemp, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { verifyRelease, versionMetadata } from "../semantic_version.mjs";

test("construit les tags RC et final compatibles avec le workflow existant", () => {
  assert.deepEqual(versionMetadata("1.3.0-rc.2"), {
    NEXT_RELEASE_VERSION: "1.3.0",
    NEXT_RC_VERSION: "1.3.0-rc.2",
    NEXT_RC_TAG: "v1.3.0-rc.2",
    NEXT_FINAL_TAG: "v1.3.0",
  });
});

test("refuse une version qui ne vient pas du canal RC", () => {
  assert.throws(
    () => versionMetadata("1.3.0"),
    /Version RC Semantic Release invalide/,
  );
});

test("écrit un rapport dotenv exploitable par GitLab", async () => {
  const directory = await mkdtemp(join(tmpdir(), "microcrm-semantic-version-"));
  const outputFile = join(directory, "semantic-version.env");
  const messages = [];

  await verifyRelease(
    { outputFile },
    {
      nextRelease: { version: "2.0.0-rc.1" },
      logger: { log: (message) => messages.push(message) },
    },
  );

  assert.equal(
    await readFile(outputFile, "utf8"),
    [
      "NEXT_RELEASE_VERSION=2.0.0",
      "NEXT_RC_VERSION=2.0.0-rc.1",
      "NEXT_RC_TAG=v2.0.0-rc.1",
      "NEXT_FINAL_TAG=v2.0.0",
      "",
    ].join("\n"),
  );
  assert.deepEqual(messages, [
    "Prochaine RC proposée : v2.0.0-rc.1",
    "Tag final correspondant : v2.0.0",
  ]);
});
