#!/usr/bin/env bash
set -Eeuo pipefail

# Preferred order of Dockerfile variants
preferredOrder=( alpine debian )

# Set the working directory to the location of the script
dir="$(dirname "$BASH_SOURCE")"
cd "$dir"

# Get the latest commit hash
commit="$(git log -1 --format='format:%H' HEAD -- .)"

# Initialize variables for version, index, jq, and base images
version=
i=0
jq= 
froms=()

# Loop through the preferred Dockerfile variants (alpine, debian)
for variant in "${preferredOrder[@]}"; do
  # Extract the base image (FROM) and version (ENV SHELLSU_VERSION or Shellsu equivalent)
  from="$(awk 'toupper($1) == "FROM" { print $2; exit }' "Dockerfile.$variant")"
  variantVersion="$(awk 'toupper($1) == "ENV" && toupper($2) == "SHELLSU_VERSION" { print $3; exit }' "Dockerfile.$variant")"
  
  # Set version if not already set
  version="${version:-$variantVersion}"
  
  # Check if version matches across variants
  if [ "$version" != "$variantVersion" ]; then
    echo >&2 "error: mismatched version in '$variant' ('$version' vs '$variantVersion')"
    exit 1
  fi
  
  # Build jq filter to get architectures
  jq="${jq:+$jq, }$variant: (.[$i] | { ref: .ref, arches: .arches | keys_unsorted })"
  
  # Store base image reference
  froms["$i"]="$from"
  
  # Increment index
  (( i++ )) || :
done

# Get architecture data from Docker images
arches="$(bashbrew remote arches --json "${froms[@]}" | jq -sc "{ $jq }")" 

# Execute jq to generate metadata for the  images
exec jq <<<"$arches" -r --arg commit "$commit" --arg version "$version" '
  map_values(select(.arches | length > 0)) 
  | keys_unsorted as $variants
  | with_entries(.value |= .arches) as $variantArches
  | ($variantArches | add | unique) as $arches
  | with_entries(.value |= (
      .ref
      | sub("^(docker[.]io/(library/)?)?"; "")
      | split(":")
      | if .[0] == "alpine" then
          join("") 
      elif .[0] == "debian" or .[0] == "ubuntu" then
          .[1] | split("-")[0] 
      else empty end
  )) as $variantAlias
  | (
      reduce (
          to_entries[]
          | {
              variant: .key,
              arch: .value.arches[],
          }
      ) as $m ({};
          if has($m.arch) then . else
            .[$m.arch] = $m.variant
          end
      )
  ) as $archVariants
  | [
      {
          Maintainers: "Dogru Ismail <is.dogru@gmail.com> (@dogruis)",
          GitRepo: "https://github.com/dogruis/shellsu.git",  # Updated to Shellsu repo
          GitCommit: $commit,
          Directory: "hub",
          Builder: "buildkit",
      },
      reduce $arches[] as $arch (
          {
              Tags: [ $version, "latest" ],
              Architectures: $arches,
              File: "Dockerfile.\($variants[0])",
          };
          if has($arch + "-File") then . else
              "Dockerfile.\($archVariants[$arch])" as $df
              | if $df == .File then . else
                  .[$arch + "-File"] = $df
              end
          end
      ),
      (
          $variants[]
          | $variantAlias[.] as $alias
          | {
              Tags: [ "\($version)-\(.)", ., "\($version)-\($alias // empty)", $alias // empty ],
              Architectures: $variantArches[.],
              File: "Dockerfile.\(.)",
          },
          (
              . as $variant
              | $variantArches[.][]
              | {
                  Tags: [ "\($variant)-\(.)", "\($alias // empty)-\(.)", if $archVariants[.] == $variant then . else empty end ],
                  Architectures: .,
                  File: "Dockerfile.\($variant)",
              }
          )
      ),
      empty
  ]
  | map(to_entries | map(.key + ": " + ([ .value ] | flatten | join(", "))) | join("\n"))
  | join("\n\n")
'
