
#!/bin/bash

set -euo pipefail  # Safer bash options

### CONFIG
REPO_URL="https://github.com/zorp-corp/nockchain"
PROJECT_DIR="$HOME/nockchain"
PUBKEY="3N3VYoXoiLmhcpGmFLEWHA6Lkzsb52QXmzEFjLnQFVr4kRrc2sT4fx85Wk6TGh1e6TMj2GHzrdfBW3gyJUbmda9aDtNvNqBHYM4NHpHnRSCpcZ9KqsrDpwJ5BToT3YVGBRpL"
ENV_FILE="$PROJECT_DIR/.env"
TMUX_SESSION="nock-miner"

echo ""
echo "[+] Nockchain MainNet Bootstrap Starting..."
echo "-------------------------------------------"

### 1. Install Rust Toolchain
echo "[1/7] Installing Rust toolchain..."
if ! command -v cargo &>/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
fi

### 2. Install System Dependencies
echo "[2/7] Installing system dependencies..."
sudo apt update && sudo apt install -y \
  git \
  make \
  build-essential \
  clang \
  llvm-dev \
  libclang-dev \
  tmux

### 3. Clone Repo & Pull Latest
echo "[3/7] Cloning or updating Nockchain repo..."
if [ ! -d "$PROJECT_DIR" ]; then
  git clone --depth 1 --branch master "$REPO_URL" "$PROJECT_DIR"
else
  cd "$PROJECT_DIR"
  git reset --hard HEAD && git pull origin master
fi
cd "$PROJECT_DIR"

### 4. Setup .env BEFORE building (fixes make error)
echo "[4/7] Creating .env file..."
cp -f .env_example .env
sed -i "s|^MINING_PUBKEY=.*|MINING_PUBKEY=$PUBKEY|" "$ENV_FILE"
grep "MINING_PUBKEY" "$ENV_FILE"

# Paranoid fallback: force pubkey override inside Makefile as well
sed -i "s|^export MINING_PUBKEY.*|export MINING_PUBKEY := $PUBKEY|" "$PROJECT_DIR/Makefile"

# Confirm both .env and Makefile have the correct pubkey
echo "[DEBUG] Confirming pubkey injection..."
grep "MINING_PUBKEY" "$ENV_FILE"
grep "MINING_PUBKEY" "$PROJECT_DIR/Makefile"

### 5. Build Nockchain
echo "[5/7] Building Nockchain..."
make install-hoonc
make build
make install-nockchain
make install-nockchain-wallet

### 6. Clean previous node data (recommended by README)
echo "[6/7] Cleaning up old chain data..."
rm -rf "$PROJECT_DIR/.data.nockchain"

### 7. Start Miner
echo "[7/7] Launching miner in tmux..."
tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
tmux new-session -d -s "$TMUX_SESSION" "cd $PROJECT_DIR && make run-nockchain | tee -a miner.log"

echo ""
echo "✅ Nockchain MainNet Miner launched successfully!"
echo "   - To view miner logs: tmux attach -t $TMUX_SESSION"
echo "   - Wallet PubKey: $PUBKEY"
echo ""
