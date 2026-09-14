import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const RC_VERSION_PATTERN = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.[1-9][0-9]*$/;

export function versionMetadata(version, existingTags = []) {
  const match = version.match(RC_VERSION_PATTERN);
  if (!match) {
    throw new Error(`Version RC Semantic Release invalide : ${version}`);
  }

  const releaseVersion = `${match[1]}.${match[2]}.${match[3]}`;
  const proposedRcNumber = Number(version.slice(version.lastIndexOf(".") + 1));
  const existingRcPattern = new RegExp(
    `^v${match[1]}\\.${match[2]}\\.${match[3]}-rc\\.([1-9][0-9]*)$`,
  );
  const highestExistingRcNumber = existingTags.reduce((highest, tag) => {
    const tagMatch = tag.match(existingRcPattern);
    return tagMatch ? Math.max(highest, Number(tagMatch[1])) : highest;
  }, 0);
  const rcNumber = Math.max(proposedRcNumber, highestExistingRcNumber + 1);
  const rcVersion = `${releaseVersion}-rc.${rcNumber}`;

  return {
    NEXT_RELEASE_VERSION: releaseVersion,
    NEXT_RC_VERSION: rcVersion,
    NEXT_RC_TAG: `v${rcVersion}`,
    NEXT_FINAL_TAG: `v${releaseVersion}`,
  };
}

export async function verifyRelease(pluginConfig, context) {
  const outputFile =
    pluginConfig.outputFile ??
    process.env.SEMANTIC_VERSION_OUTPUT ??
    ".ci/release/semantic-version.env";
  const existingTags =
    pluginConfig.existingTags ??
    (process.env.SEMANTIC_RELEASE_EXISTING_TAGS ?? "")
      .split(/\r?\n/)
      .filter(Boolean);
  const metadata = versionMetadata(context.nextRelease.version, existingTags);
  const content = `${Object.entries(metadata)
    .map(([key, value]) => `${key}=${value}`)
    .join("\n")}\n`;

  await mkdir(dirname(outputFile), { recursive: true });
  await writeFile(outputFile, content, "utf8");

  context.logger.log(`Prochaine RC proposée : ${metadata.NEXT_RC_TAG}`);
  context.logger.log(`Tag final correspondant : ${metadata.NEXT_FINAL_TAG}`);
}
