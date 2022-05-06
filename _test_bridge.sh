#!/bin/sh


export NETWORK_TYPE=1;

    node test/bridge_1_deploy_sample_erc721.js
    if [ $? != 0 ]; then
        exit
    fi

    node test/bridge_2_mint_multichain_nfts.js
    if [ $? != 0 ]; then
        exit
    fi

    node test/bridge_3_transfer_multichain_nfts.js
    if [ $? != 0 ]; then
        exit
    fi


export NETWORK_TYPE=1;

    echo ""
    echo ""


exit