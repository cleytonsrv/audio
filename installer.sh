#!/bin/bash

# Cores para formatação
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem cor

echo -e "${YELLOW}"
echo "    _                           _        _    ___ "
echo "   / \\   __ _  ___ _ __   __| | ___  / \\  |_ _|"
echo "  / _ \\ / _\` |/ _ \\ '_ \\ / _\` |/ _ \\/ _ \\  | | "
echo " / ___ \\ (_| |  __/ | | | (_| |  __/ ___ \\ | | "
echo "/_/   \\_\\__, |\\___|_| |_|\\__,_|\\___/_/   \\_\\___|"
echo "        |___/                                   "
echo -e "${NC}"
echo -e "${GREEN}Sistema de Agendamento - Instalador${NC}\n"

echo -e "Baixando instalador principal...\n"

# Criar diretório temporário
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

# Baixar arquivos de instalação
curl -s -o install.sh https://raw.githubusercontent.com/cleytonsrv/my-scheduler-app/main/install.sh

# Tornar executável
chmod +x install.sh

echo -e "\n${GREEN}Iniciando instalador...${NC}\n"

# Executar instalador
./install.sh

# Limpar arquivos temporários ao sair
trap "rm -rf $TMP_DIR" EXIT
