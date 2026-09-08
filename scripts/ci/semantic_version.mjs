import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";

const RC_VERSION_PATTERN = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-rc\.[1-9][0-9]*$/;

export function versionMetadata(version) {
  if (!RC_VERSION_PATTERN.test(version)) {
    throw new Error(`Version RC Semantic Release invalide : ${version}`);
  }

  const releaseVersion = version.replace(/-rc\.[1-9][0-9]*$/, "");
  return {
    NEXT_RELEASE_VERSION: releaseVersion,
    NEXT_RC_VERSION: version,
    NEXT_RC_TAG: `v${version}`,
    NEXT_FINAL_TAG: `v${releaseVersion}`,
  };
}

export async function verifyRelease(pluginConfig, context) {
  const outputFile =
    pluginConfig.outputFile ??
    process.env.SEMANTIC_VERSION_OUTPUT ??
    ".ci/release/semantic-version.env";
  const metadata = versionMetadata(context.nextRelease.version);
  const content = `${Object.entries(metadata)
    .map(([key, value]) => `${key}=${value}`)
    .join("\n")}\n`;

  await mkdir(dirname(outputFile), { recursive: true });
  await writeFile(outputFile, content, "utf8");

  context.logger.log(`Prochaine RC proposée : ${metadata.NEXT_RC_TAG}`);
  context.logger.log(`Tag final correspondant : ${metadata.NEXT_FINAL_TAG}`);
}
