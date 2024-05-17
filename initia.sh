#!/bin/bash

fmt=`tput setaf 45`
end="\e[0m\n"
err="\e[31m"
scss="\e[32m"

CHAIN_ID="initiation-1"
DENOM="initiad"
VERSION="v0.2.14"
NODE_PORT=26657

cd $HOME

echo -e "${fmt}\nInitia installation${end}" && sleep 3

if [ -z "$MONIKER" ]; then
  echo -e "${err}\nYou have not set MONIKER, please set the variable and try again${end}" && sleep 1
  exit 1;
fi

echo -e "${fmt}\nSetting up dependencies${end}" && sleep 1


sudo apt update && sudo apt upgrade -y
sudo apt install curl tar clang pkg-config libssl-dev libleveldb-dev jq build-essential bsdmainutils git make ncdu htop lz4 unzip bc -y


echo -e "${fmt}\nInstall go${end}" && sleep 1

cd $HOME && \
ver="1.22.0" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version


echo -e "${fmt} Downloading and building binaries ${end}" && sleep 1

git clone https://github.com/initia-labs/initia.git
cd initia
git checkout $VERSION
make install

if ! command initiad &> /dev/null; then
  echo -e "${err} Initia binary not found${end}" && sleep 1
  exit 1;
fi

echo -e "${fmt} Setup initiad${end}" && sleep 1

initiad config chain-id $CHAIN_ID
initiad config set client keyring-backend test
initiad config set client node tcp://localhost:$NODE_PORT
initiad init "$MONIKER" --chain-id $CHAIN_ID


echo -e "${fmt} Download and set up genesis.json, addrbook.json${end}" && sleep 1

curl -L https://snapshot.validatorvn.com/initia/addrbook.json > $HOME/.initia/config/addrbook.json
sudo wget https://initia.s3.ap-southeast-1.amazonaws.com/initiation-1/genesis.json -O $HOME/.initia/config/genesis.json


echo -e "${fmt} Setup seed, peers, config pruning, set gas price, disable indexing, enable prometheus${end}" && sleep 1

sed -i -e "s|^seeds *=.*|seeds = \"3f472746f46493309650e5a033076689996c8881@initia-testnet.rpc.kjnodes.com:17959\"|" $HOME/.initia/config/config.toml
PEERS="aee7083ab11910ba3f1b8126d1b3728f13f54943@initia-testnet-peer.itrocket.net:11656,2bfad62fa5ba7cc91af4e19ee8d1356997a01079@84.247.166.24:51656,e6a35b95ec73e511ef352085cb300e257536e075@37.252.186.213:26656,07632ab562028c3394ee8e78823069bfc8de7b4c@37.27.52.25:19656,b4778656f255169b8b1d660b6af3a0df68d68e65@176.57.189.36:15656,54d2302155d1bd2a95354ea1d54e196db70a5361@84.46.251.215:656,767fdcfdb0998209834b929c59a2b57d474cc496@207.148.114.112:26656,093e1b89a498b6a8760ad2188fbda30a05e4f300@35.240.207.217:26656,5f934bd7a9d60919ee67968d72405573b7b14ed0@65.21.202.124:29656,e15f6e83d7e35c12f99476674137f3edd1865654@161.97.143.182:16656"
sed -i 's|^persistent_peers *=.*|persistent_peers = "'$PEERS'"|' $HOME/.initia/config/config.toml

sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.initia/config/app.toml

sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.15uinit,0.01uusdc"|g' $HOME/.initia/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.initia/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.initia/config/config.toml
sed -i 's|^prometheus *=.*|prometheus = true|' $HOME/.initia/config/config.toml


sudo tee /etc/systemd/system/initiad.service > /dev/null <<EOF
[Unit]
Description=Initia node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.initia
ExecStart=$(which initiad) start --home $HOME/.initia
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable initiad.service
sudo systemctl start initiad


echo -e "${fmt}Node installed successfully${end}" && sleep 1
