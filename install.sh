#!/bin/bash

# Cores para formatação de saída
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem cor

# Logo do AgendAI
show_logo() {
    clear
    echo -e "${BLUE}"
    echo "    _                           _        _    ___ "
    echo "   / \\   __ _  ___ _ __   __| | ___  / \\  |_ _|"
    echo "  / _ \\ / _\` |/ _ \\ '_ \\ / _\` |/ _ \\/ _ \\  | | "
    echo " / ___ \\ (_| |  __/ | | | (_| |  __/ ___ \\ | | "
    echo "/_/   \\_\\__, |\\___|_| |_|\\__,_|\\___/_/   \\_\\___|"
    echo "        |___/                                   "
    echo -e "${NC}"
    echo -e "${YELLOW}Sistema de Agendamento - Instalador Automático${NC}\n"
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" &> /dev/null
}

# Função para confirmar ação
confirm() {
    read -p "$1 [s/n]: " choice
    case "$choice" in
        s|S) return 0 ;;
        *) return 1 ;;
    esac
}

# Função para instalar dependências do sistema
install_dependencies() {
    echo -e "\n${YELLOW}Instalando dependências do sistema...${NC}"
    
    # Atualizar lista de pacotes
    sudo apt-get update
    
    # Instalar dependências básicas
    sudo apt-get install -y git curl wget nano build-essential nginx

    # Instalar Node.js e npm
    if ! command_exists node; then
        echo -e "\n${YELLOW}Instalando Node.js e npm...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        # Verificar instalação
        node_version=$(node -v)
        npm_version=$(npm -v)
        echo -e "${GREEN}Node.js $node_version e npm $npm_version instalados com sucesso!${NC}"
    else
        echo -e "${GREEN}Node.js já está instalado.${NC}"
    fi
    
    # Instalar PM2 globalmente para gestão de processos
    if ! command_exists pm2; then
        echo -e "\n${YELLOW}Instalando PM2...${NC}"
        sudo npm install -g pm2
        echo -e "${GREEN}PM2 instalado com sucesso!${NC}"
    else
        echo -e "${GREEN}PM2 já está instalado.${NC}"
    fi
    
    echo -e "${GREEN}Todas as dependências do sistema foram instaladas com sucesso!${NC}"
}

# Função para configurar o NGINX como proxy reverso
configure_nginx() {
    local domain=$1
    local port=$2
    
    echo -e "\n${YELLOW}Configurando NGINX para $domain...${NC}"
    
    # Criar configuração para o site
    sudo tee /etc/nginx/sites-available/$domain > /dev/null << EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

    # Habilitar o site
    sudo ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    
    # Remover configuração padrão se existir
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Testar configuração e reiniciar NGINX
    sudo nginx -t && sudo systemctl restart nginx
    
    echo -e "${GREEN}NGINX configurado com sucesso!${NC}"
}

# Função para configurar SSL com Let's Encrypt
configure_ssl() {
    local domain=$1
    
    echo -e "\n${YELLOW}Configurando SSL para $domain com Let's Encrypt...${NC}"
    
    # Instalar Certbot
    sudo apt-get install -y certbot python3-certbot-nginx
    
    # Obter certificado SSL
    sudo certbot --nginx -d $domain --non-interactive --agree-tos --email admin@$domain
    
    echo -e "${GREEN}SSL configurado com sucesso!${NC}"
}

# Função para clonar ou atualizar o repositório
clone_or_update_repo() {
    local repo_url=$1
    local app_dir=$2
    
    if [ -d "$app_dir/.git" ]; then
        echo -e "\n${YELLOW}Repositório existente encontrado, atualizando...${NC}"
        cd $app_dir
        git fetch --all
        git reset --hard origin/main
    else
        echo -e "\n${YELLOW}Clonando o repositório...${NC}"
        git clone $repo_url $app_dir
    fi
    
    echo -e "${GREEN}Repositório atualizado com sucesso!${NC}"
}

# Função para configurar variáveis de ambiente
configure_env() {
    local app_dir=$1
    local supabase_url=$2
    local supabase_key=$3
    
    echo -e "\n${YELLOW}Configurando variáveis de ambiente...${NC}"
    
    # Criar arquivo .env ou atualizar existente
    cat > $app_dir/.env << EOF
NEXT_PUBLIC_SUPABASE_URL=$supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=$supabase_key
EOF

    echo -e "${GREEN}Variáveis de ambiente configuradas com sucesso!${NC}"
}

# Função para instalar dependências do projeto
install_project_dependencies() {
    local app_dir=$1
    
    echo -e "\n${YELLOW}Instalando dependências do projeto...${NC}"
    
    cd $app_dir
    npm install --production
    
    echo -e "${GREEN}Dependências do projeto instaladas com sucesso!${NC}"
}

# Função para compilar o projeto
build_project() {
    local app_dir=$1
    
    echo -e "\n${YELLOW}Compilando o projeto...${NC}"
    
    cd $app_dir
    npm run build
    
    echo -e "${GREEN}Projeto compilado com sucesso!${NC}"
}

# Função para iniciar a aplicação com PM2
start_application() {
    local app_dir=$1
    local app_name=$2
    
    echo -e "\n${YELLOW}Iniciando a aplicação com PM2...${NC}"
    
    cd $app_dir
    
    # Verificar se a aplicação já está configurada no PM2
    if pm2 list | grep -q "$app_name"; then
        pm2 reload $app_name
    else
        pm2 start npm --name "$app_name" -- start
    fi
    
    # Configurar para iniciar automaticamente após reinicialização
    pm2 save
    sudo env PATH=$PATH:/usr/bin pm2 startup systemd -u $USER --hp $HOME
    
    echo -e "${GREEN}Aplicação iniciada com sucesso!${NC}"
}

# Instalação completa do zero
fresh_install() {
    local app_name="my-scheduler-app"
    local app_dir="/var/www/$app_name"
    local repo_url="https://github.com/cleytonsrv/my-scheduler-app.git"
    
    # Coletar informações
    echo -e "\n${YELLOW}Configuração de nova instalação${NC}"
    
    # Domínio
    read -p "Digite o domínio para acessar a aplicação (ex: agenda.seudominio.com): " domain
    
    # Porta
    read -p "Digite a porta para a aplicação (ex: 3000): " port
    
    # Credenciais Supabase
    read -p "Digite a URL do Supabase: " supabase_url
    read -p "Digite a chave anônima do Supabase: " supabase_key
    
    # Se for repositório privado
    read -p "O repositório é privado? (s/n): " is_private
    if [[ "$is_private" == "s" || "$is_private" == "S" ]]; then
      read -p "Digite seu token de acesso ao GitHub: " github_token
      repo_url="https://${github_token}@github.com/cleytonsrv/my-scheduler-app.git"
    fi
    
    # Confirmar
    echo -e "\n${YELLOW}Resumo da instalação:${NC}"
    echo -e "Domínio: ${GREEN}$domain${NC}"
    echo -e "Porta: ${GREEN}$port${NC}"
    echo -e "Diretório: ${GREEN}$app_dir${NC}"
    
    if ! confirm "Deseja prosseguir com a instalação?"; then
        echo -e "${RED}Instalação cancelada.${NC}"
        return 1
    fi
    
    # Instalar dependências
    install_dependencies
    
    # Criar diretório do aplicativo se não existir
    sudo mkdir -p $app_dir
    sudo chown -R $USER:$USER $app_dir
    
    # Clonar repositório
    clone_or_update_repo $repo_url $app_dir
    
    # Configurar variáveis de ambiente
    configure_env $app_dir $supabase_url $supabase_key
    
    # Instalar dependências do projeto
    install_project_dependencies $app_dir
    
    # Compilar o projeto
    build_project $app_dir
    
    # Configurar NGINX
    configure_nginx $domain $port
    
    # Configurar SSL
    if confirm "Deseja configurar SSL/HTTPS para o domínio $domain?"; then
        configure_ssl $domain
    fi
    
    # Iniciar aplicação
    start_application $app_dir $app_name
    
    echo -e "\n${GREEN}Instalação concluída com sucesso!${NC}"
    echo -e "Sua aplicação está disponível em: ${BLUE}https://$domain${NC}"
}

# Atualização de uma instalação existente
update_installation() {
    local app_name="my-scheduler-app"
    
    echo -e "\n${YELLOW}Atualização de instalação existente${NC}"
    
    # Diretório
    read -p "Digite o diretório da instalação existente (ex: /var/www/my-scheduler-app): " app_dir
    
    if [ ! -d "$app_dir" ]; then
        echo -e "${RED}Diretório não encontrado. Verifique o caminho e tente novamente.${NC}"
        return 1
    fi
    
    # Se for repositório privado
    local repo_url="https://github.com/cleytonsrv/my-scheduler-app.git"
    read -p "O repositório é privado? (s/n): " is_private
    if [[ "$is_private" == "s" || "$is_private" == "S" ]]; then
      read -p "Digite seu token de acesso ao GitHub: " github_token
      repo_url="https://${github_token}@github.com/cleytonsrv/my-scheduler-app.git"
    fi
    
    # Confirmar
    if ! confirm "Deseja atualizar a instalação em $app_dir?"; then
        echo -e "${RED}Atualização cancelada.${NC}"
        return 1
    fi
    
    # Atualizar código
    clone_or_update_repo $repo_url $app_dir
    
    # Atualizar dependências
    install_project_dependencies $app_dir
    
    # Compilar o projeto
    build_project $app_dir
    
    # Reiniciar aplicação
    start_application $app_dir $app_name
    
    echo -e "\n${GREEN}Atualização concluída com sucesso!${NC}"
}

# Menu principal
main_menu() {
    show_logo
    echo "Selecione uma opção:"
    echo "1) Instalação nova (do zero)"
    echo "2) Atualizar instalação existente"
    echo "3) Sair"
    echo
    
    read -p "Opção: " option
    
    case $option in
        1) fresh_install ;;
        2) update_installation ;;
        3) echo -e "${YELLOW}Saindo...${NC}"; exit 0 ;;
        *) echo -e "${RED}Opção inválida!${NC}"; main_menu ;;
    esac
}

# Iniciar instalador
main_menu
