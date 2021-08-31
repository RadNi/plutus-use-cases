#!/usr/bin/env bash
set -euo pipefail

# In case we need to start node and wait till it synced

# echo "Starting node"
# cardano-node run \
#   --topology /home/cardano-my-node/alonzo-purple-topology.json \
#   --database-path /home/cardano-my-node/db \
#   --socket-path /home/cardano-my-node/db/socket \
#   --host-addr 0.0.0.0 \
#   --port 6000 \
#   --config /home/cardano-my-node/alonzo-purple-config.json \
#   > /dev/null 2>&1 &

# sleep 10
# echo "Node started"
# echo "Waiting node to sync"

# tip=$(cardano-cli query tip $MAGIC)
# while  [ "$(echo $tip | jq '.syncProgress')" != "\"100.00\"" ]; do
#         echo $tip
#         echo "Waiting 20 seconds more..."
#         sleep 20
#         tip=$(cardano-cli query tip $MAGIC)
# done
# echo "Node synced"

# In case we need to start node and wait till it synced - END

echo "Node synced. Building NFT-sript address"
cardano-cli address build ${MAGIC} \
    --payment-script-file .github/workflows/nft_delivery/NftScript.plutus \
    --out-file .github/workflows/nft_delivery/nft-script-payment.addr

echo "NFT-sript address created"