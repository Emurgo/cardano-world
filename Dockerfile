
FROM nixos/nix:latest AS builder
RUN nix-env -iA nixpkgs.ps
RUN mkdir -p /etc/nix
RUN touch /etc/nix/nix.conf
# Set environment variables
#ENV IOHK_NIX=$(nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).inputs.iohk-nix.outPath')
#ENV TEMPLATE_DIR="$IOHK_NIX/cardano-lib/testnet-template"
ENV SECURITY_PARAM=432
ENV NUM_GENESIS_KEYS=7
ENV SLOT_LENGTH=100
ENV TESTNET_MAGIC=2
ENV START_TIME="2022-08-11T14:00:00Z"
ENV PRJ_ROOT="/cardano-world"
ENV GENESIS_DIR="workbench/custom"
ENV ENV_NAME="preprod"
ENV NUM_GENESIS_KEYS=7
ENV CARDANO_NODE_SOCKET_PATH="/cardano-world/node.socket"

# Install dependencies and set up the environment
RUN nix-channel --add https://nixos.org/channels/nixos-22.05 nixos \
    && nix-channel --update

RUN nix-env -iA nixpkgs.haskellPackages.ghc \
             nixpkgs.haskellPackages.cabal-install \
             nixpkgs.libsodium
RUN git clone https://github.com/IntersectMBO/cardano-world.git
WORKDIR /cardano-world
RUN wget https://book.play.dev.cardano.org/environments/preprod/config.json && wget https://book.play.dev.cardano.org/environments/preprod/topology.json && wget https://book.play.dev.cardano.org/environments/preprod/byron-genesis.json && wget https://book.play.dev.cardano.org/environments/preprod/shelley-genesis.json && wget https://book.play.dev.cardano.org/environments/preprod/alonzo-genesis.json && wget https://book.play.dev.cardano.org/environments/preprod/conway-genesis.json
RUN echo "donotUnpack = true" > /etc/nix/nix.conf && echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf && echo "allow-import-from-derivation = true" >> /etc/nix/nix.conf && echo "extra-experimental-features = fetch-closure" >> /etc/nix/nix.conf
RUN ls -ltr flake*
#ENV IOHK_NIX=$(nix eval --raw --impure --expr '(builtins.getFlake ./).inputs.iohk-nix.outPath')
ENV TEMPLATE_DIR="/nix/store/*-source/cardano-lib/testnet-template"

# Run the `gen-custom-node-config` job to generate node config
RUN nix build --accept-flake-config --show-trace .#x86_64-linux.automation.jobs.gen-custom-node-config

# Run the `gen-custom-kv-config` job to generate key value config
RUN nix build --accept-flake-config --show-trace .#x86_64-linux.automation.jobs.gen-custom-kv-config

RUN nix build  --accept-flake-config .#cardano-node -o cardano-node

# Install cardano-node (you may need to customize the installation step depending on the method you use)
#RUN nix-env -iA nixpkgs.cardano-node

# Expose port for cardano-node (default port for cardano-node is 3001)
EXPOSE 3001
RUN which cardano-node
# Start cardano-node
CMD cardano-node run \
    --config workbench/custom/config.json \
    --database-path ~/.local/share/bitte/cardano/db-preprod/node \
    --topology "/cardano-world/workbench/custom/topology.json" \
    +RTS -N2 -A16m -qg -qb -M3584.000000M -RTS \
    --socket-path node.socket \
    --shelley-kes-key workbench/custom/delegate-keys/shelley.000.kes.skey \
    --shelley-vrf-key workbench/custom/delegate-keys/shelley.000.vrf.skey \
    --shelley-operational-certificate workbench/custom/delegate-keys/shelley.000.opcert.json
