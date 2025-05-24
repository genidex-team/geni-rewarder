#!/bin/bash

# cd ..
NETWORK=$1

echo "";
echo "================= deploy.js ================="
npx hardhat run scripts/deploy.js --network $NETWORK
