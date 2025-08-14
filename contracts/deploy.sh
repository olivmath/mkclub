#!/bin/bash

# Script de Deploy do Contrato CW Counter
# Baseado nas instruções do README.md

set -e  # Para o script se houver erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Network configuration - XION TESTNET
CHAIN_ID="xion-testnet-2"
RPC_ENDPOINT="https://rpc.xion-testnet-2.burnt.com:443"
GAS_DENOM="uxion"
GAS_PRICE="0.025"
STORE_GAS_PRICE="0.1"

echo -e "${BLUE}=== Script de Deploy do CW Counter (XION Testnet) ===${NC}"

# Verificar se o endereço da wallet foi fornecido
if [ -z "$1" ]; then
    echo -e "${RED}Erro: Endereço da wallet é obrigatório${NC}"
    echo "Uso: ./deploy.sh <wallet-address> [initial-count]"
    echo "Exemplo: ./deploy.sh xion1abc123... 1"
    exit 1
fi

WALLET="$1"
INITIAL_COUNT="${2:-1}"  # Valor padrão é 1 se não fornecido

echo -e "${YELLOW}Network: XION Testnet (${CHAIN_ID})${NC}"
echo -e "${YELLOW}RPC: ${RPC_ENDPOINT}${NC}"
echo -e "${YELLOW}Wallet: $WALLET${NC}"
echo -e "${YELLOW}Contador inicial: $INITIAL_COUNT${NC}"
echo ""

# Verificar se o podman está rodando
if ! podman info > /dev/null 2>&1; then
    echo -e "${RED}Erro: podman não está rodando. Por favor, inicie o podman.${NC}"
    exit 1
fi

# Verificar se xiond está instalado
if ! command -v xiond &> /dev/null; then
    echo -e "${RED}Erro: xiond não está instalado. Instale seguindo: https://docs.burnt.com/xion/developers/featured-guides/setup-local-environment/interact-with-xion-chain-setup-xion-daemon${NC}"
    exit 1
fi

# Verificar se jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Erro: jq não está instalado. Instale com: brew install jq${NC}"
    exit 1
fi

echo -e "${BLUE}Passo 1: Compilando e otimizando o contrato...${NC}"

# Compilar e otimizar o contrato
podman run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/optimizer:0.16.0

if [ ! -f "./artifacts/cw_counter.wasm" ]; then
    echo -e "${RED}Erro: Arquivo cw_counter.wasm não foi gerado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contrato compilado e otimizado com sucesso${NC}"
echo ""

echo -e "${BLUE}Passo 2: Fazendo upload do bytecode para a blockchain...${NC}"

# Upload do contrato
RES=$(xiond tx wasm store ./artifacts/cw_counter.wasm \
      --chain-id $CHAIN_ID \
      --gas-adjustment 1.3 \
      --gas-prices ${STORE_GAS_PRICE}${GAS_DENOM} \
      --gas auto \
      -y --output json \
      --node $RPC_ENDPOINT \
      --from $WALLET)

echo -e "${YELLOW}Resposta do upload:${NC}"
echo $RES | jq .

# Extrair o transaction hash
TXHASH=$(echo $RES | jq -r '.txhash')

if [ "$TXHASH" = "null" ] || [ -z "$TXHASH" ]; then
    echo -e "${RED}Erro: Não foi possível obter o transaction hash${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Upload realizado com sucesso${NC}"
echo -e "${YELLOW}Transaction Hash: $TXHASH${NC}"
echo ""

echo -e "${BLUE}Aguardando confirmação da transação...${NC}"
sleep 10

echo -e "${BLUE}Passo 3: Obtendo o Code ID...${NC}"

# Obter o Code ID
CODE_ID=$(xiond query tx $TXHASH \
  --node $RPC_ENDPOINT \
  --output json | jq -r '.events[-1].attributes[1].value')

if [ "$CODE_ID" = "null" ] || [ -z "$CODE_ID" ]; then
    echo -e "${RED}Erro: Não foi possível obter o Code ID${NC}"
    echo "Verifique se a transação foi confirmada e tente novamente"
    exit 1
fi

echo -e "${GREEN}✓ Code ID obtido: $CODE_ID${NC}"
echo ""

echo -e "${BLUE}Passo 4: Instanciando o contrato...${NC}"

# Mensagem de inicialização
MSG="{ \"count\": $INITIAL_COUNT }"
echo -e "${YELLOW}Mensagem de inicialização: $MSG${NC}"

# Instanciar o contrato
INSTANTIATE_RES=$(xiond tx wasm instantiate $CODE_ID "$MSG" \
  --from $WALLET \
  --label "cw-counter" \
  --gas-prices ${GAS_PRICE}${GAS_DENOM} \
  --gas auto \
  --gas-adjustment 1.3 \
  -y --no-admin \
  --chain-id $CHAIN_ID \
  --node $RPC_ENDPOINT \
  --output json)

echo -e "${YELLOW}Resposta da instanciação:${NC}"
echo $INSTANTIATE_RES | jq .

# Extrair o transaction hash da instanciação
INSTANTIATE_TXHASH=$(echo $INSTANTIATE_RES | jq -r '.txhash')

if [ "$INSTANTIATE_TXHASH" = "null" ] || [ -z "$INSTANTIATE_TXHASH" ]; then
    echo -e "${RED}Erro: Não foi possível obter o transaction hash da instanciação${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Contrato instanciado com sucesso${NC}"
echo -e "${YELLOW}Transaction Hash da instanciação: $INSTANTIATE_TXHASH${NC}"
echo ""

echo -e "${BLUE}Aguardando confirmação da instanciação...${NC}"
sleep 10

echo -e "${BLUE}Passo 5: Obtendo o endereço do contrato...${NC}"

# Obter o endereço do contrato
CONTRACT=$(xiond query tx $INSTANTIATE_TXHASH \
  --node $RPC_ENDPOINT \
  --output json | jq -r '.events[] | select(.type == "instantiate") | .attributes[] | select(.key == "_contract_address") | .value')

if [ "$CONTRACT" = "null" ] || [ -z "$CONTRACT" ]; then
    echo -e "${RED}Erro: Não foi possível obter o endereço do contrato${NC}"
    echo "Verifique se a transação foi confirmada e tente novamente"
    exit 1
fi

echo -e "${GREEN}✓ Endereço do contrato obtido: $CONTRACT${NC}"
echo ""

echo -e "${GREEN}=== DEPLOY CONCLUÍDO COM SUCESSO ===${NC}"
echo -e "${BLUE}Resumo:${NC}"
echo -e "  Network: ${YELLOW}XION Testnet (${CHAIN_ID})${NC}"
echo -e "  Wallet: ${YELLOW}$WALLET${NC}"
echo -e "  Code ID: ${YELLOW}$CODE_ID${NC}"
echo -e "  Endereço do Contrato: ${YELLOW}$CONTRACT${NC}"
echo -e "  Contador Inicial: ${YELLOW}$INITIAL_COUNT${NC}"
echo ""
echo -e "${BLUE}Para interagir com o contrato, use:${NC}"
echo -e "${YELLOW}# Consultar contador atual:${NC}"
echo "xiond query wasm contract-state smart $CONTRACT '{\"get_count\": {}}' --node $RPC_ENDPOINT"
echo ""
echo -e "${YELLOW}# Incrementar contador:${NC}"
echo "xiond tx wasm execute $CONTRACT '{\"increment_counter\": {}}' --from $WALLET --chain-id $CHAIN_ID --gas-prices ${GAS_PRICE}${GAS_DENOM} --gas auto --gas-adjustment 1.3 -y --node $RPC_ENDPOINT"
echo ""
echo -e "${YELLOW}# Resetar contador:${NC}"
echo "xiond tx wasm execute $CONTRACT '{\"reset_counter\": {\"count\": 0}}' --from $WALLET --chain-id $CHAIN_ID --gas-prices ${GAS_PRICE}${GAS_DENOM} --gas auto --gas-adjustment 1.3 -y --node $RPC_ENDPOINT"

# Salvar informações em arquivo
echo "NETWORK=xion-testnet-1" > .env.deploy
echo "RPC_ENDPOINT=$RPC_ENDPOINT" >> .env.deploy
echo "WALLET=$WALLET" >> .env.deploy
echo "CODE_ID=$CODE_ID" >> .env.deploy
echo "CONTRACT_ADDRESS=$CONTRACT" >> .env.deploy
echo "INITIAL_COUNT=$INITIAL_COUNT" >> .env.deploy

echo ""
echo -e "${GREEN}✓ Informações salvas em .env.deploy${NC}"