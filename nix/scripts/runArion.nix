{ pkgs, ... }: "${(pkgs.writeShellScriptBin "runArion.sh" ''

#!/usr/bin/env bash

upsearch () {
  local slashes=''\${PWD//[^\/]/}
  local directory=$(pwd)
  for (( n=''\${#slashes}; n>0; --n ))
  do
    test -e "$directory/$1" && cd $directory 
    directory="$directory/.."
  done
}

upsearch flake.nix

${pkgs.arion}/bin/arion build
${pkgs.arion}/bin/arion config > docker-compose.yml
${pkgs.podman-compose}/bin/podman-compose up -d

'')}/bin/runArion.sh"