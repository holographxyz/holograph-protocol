#!/bin/bash
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RESET='\033[0m' # No Color

node1Pid=$(lsof -ti:8545)
if [ $? -ne 0 ]; then
  printf "Port ${CYAN}8545${RESET} is ${GREEN}free${RESET}\n"
else
  printf "Killing anvil ${GREEN}node1${RESET}(#${node1Pid}):${CYAN}8545${RESET}\n"
  kill $(lsof -ti:8545)
fi

node2Pid=$(lsof -ti:9545)
if [ $? -ne 0 ]; then
  printf "Port ${CYAN}9545${RESET} is ${GREEN}free${RESET}\n"
else
  printf "Killing anvil ${GREEN}node2${RESET}(#${node2Pid}):${CYAN}9545${RESET}\n"
  kill $(lsof -ti:9545)
fi

printf "\n"