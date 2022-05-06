#!/bin/sh

## we loop two times to cover networks 1 and 2
for network in 1 2
do

    export NETWORK_TYPE=$network;

        node deploy/0_fund_deployer.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/1_deploy_holograph_genesis.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/2_deploy_sources.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/3_set_pa1d_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/4_deploy_holograph_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/5_test_holograph_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/6_set_holograph_erc721_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/7_deploy_sample_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/8_test_sample_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/9_mint_sample_token.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/10_test_nft_functionality.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/11_deploy_holograph_erc20.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/12_test_holograph_erc20.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/13_set_holograph_erc20_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/14_deploy_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/15_test_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/16_mint_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node deploy/17_test_hToken_functionality.js
        if [ $? != 0 ]; then
            exit
        fi

done

export NETWORK_TYPE=1;

    echo ""
    echo ""


exit