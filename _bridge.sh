#!/bin/sh

node deploy/bridge_1_deploy_sample_erc721.js
if [ $? != 0 ]; then
    exit
fi
node deploy/bridge_2_mint_multichain_nfts.js
if [ $? != 0 ]; then
    exit
fi
node deploy/bridge_3_transfer_multichain_nfts.js
if [ $? != 0 ]; then
    exit
fi
# node deploy/.js &&
# node deploy/.js &&

echo ""
echo ""

exit