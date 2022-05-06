#!/bin/sh

## we loop two times to cover networks 1 and 2
for network in 1 2
do

    export NETWORK_TYPE=$network;

        node test/0_fund_deployer.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/1_deploy_holograph_genesis.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/2_deploy_sources.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/3_set_pa1d_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/4_deploy_holograph_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/5_test_holograph_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/6_set_holograph_erc721_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/7_deploy_sample_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/8_test_sample_erc721.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/9_mint_sample_token.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/10_test_nft_functionality.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/11_deploy_holograph_erc20.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/12_test_holograph_erc20.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/13_set_holograph_erc20_type.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/14_deploy_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/15_test_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/16_mint_hToken.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/17_deploy_mock_tokens.js
        if [ $? != 0 ]; then
            exit
        fi

        node test/18_test_hToken_functionality.js
        if [ $? != 0 ]; then
            exit
        fi

done

export NETWORK_TYPE=1;

    echo ""
    echo ""


exit