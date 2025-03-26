#!/bin/bash

cd ..
NETWORK=$1

echo "";
echo "================= upgrade.js ================="
npx hardhat run scripts/upgrade.js --network $NETWORK
