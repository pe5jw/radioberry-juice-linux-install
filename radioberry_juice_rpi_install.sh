#!/bin/bash
# =============================================================================
# Radioberry 2.x + Juice Board - Raspberry Pi 4 / Pi 5 Install Script
# =============================================================================
# Verbindt de Radioberry via het Juice Board (FT2232H) via USB met een RPi4/5.
# Gebaseerd op het werk van Johan PA3GSB - https://www.pa3gsb.nl
# GitHub: https://github.com/pa3gsb/Radioberry-2.x
#
# Wat dit script doet:
#   1. Pi model detecteren (Pi4 / Pi5)
#   2. Vereiste pakketten installeren (libftdi, build tools, GPIO libs)
#   3. ftdi_sio kernelmodule blokkeren
#   4. udev regels instellen voor FT2232H
#   5. Radioberry Juice firmware downloaden en bouwen
#   6. Gateware (.rbf) installeren
#   7. Systemd service aanmaken
#   8. Optioneel: piHPSDR / Quisk installeren
#
# Ondersteund:
#   - Raspberry Pi 4 (Raspberry Pi OS Bullseye / Bookworm)
#   - Raspberry Pi 5 (Raspberry Pi OS Bookworm)
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WAARSCHUWING]${NC} $1"; }
error() { echo -e "${RED}[FOUT]${NC} $1"; exit 1; }
info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
title() { echo -e "${CYAN}$1${NC}"; }

echo ""
echo "============================================================"
echo "  Radioberry 2.x Juice Board"
echo "  Raspberry Pi 4 / Pi 5 - USB Installatie"
echo "  PA3GSB - https://www.pa3gsb.nl"
echo "============================================================"
echo ""

# --- Root check ---
if [ "$EUID" -eq 0 ]; then
  error "Voer dit script NIET uit als root. Gebruik de 'pi' gebruiker (sudo wordt waar nodig gevraagd)."
fi

# =============================================================================
# Pi model detecteren
# =============================================================================
detect_pi_model() {
  if [ ! -f /proc/device-tree/model ]; then
    error "Geen Raspberry Pi gedetecteerd. Dit script is alleen voor RPi 4/5."
  fi
  PI_MODEL=$(cat /proc/device-tree/model)
  info "Hardware gedetecteerd: $PI_MODEL"

  if echo "$PI_MODEL" | grep -q "Raspberry Pi 5"; then
    PI_VERSION=5
    log "Raspberry Pi 5 gedetecteerd."
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 4"; then
    PI_VERSION=4
    log "Raspberry Pi 4 gedetecteerd."
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 3"; then
    PI_VERSION=3
    warn "Raspberry Pi 3 gedetecteerd. Niet officieel ondersteund, doorgaan op eigen risico."
    PI_VERSION=3
  else
    error "Onbekend Pi model: $PI_MODEL. Dit script ondersteunt Pi 4 en Pi 5."
  fi
}

# OS versie bepalen
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_CODENAME=${VERSION_CODENAME:-unknown}
    info "OS: $PRETTY_NAME (codename: $OS_CODENAME)"
  else
    error "Kan OS niet bepalen."
  fi
}

detect_pi_model
detect_os

# =============================================================================
# STAP 1: Systeem updaten en pakketten installeren
# =============================================================================
echo ""
title "STAP 1: Systeem updaten en pakketten installeren..."

sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Basis build tools + FTDI + audio + GPIO
PACKAGES="build-essential git cmake pkg-config wget unzip \
  libftdi1 libftdi1-dev \
  libusb-1.0-0 libusb-1.0-0-dev \
  libfftw3-dev \
  libasound2-dev \
  libpulse-dev \
  libgtk-3-dev \
  libgpiod-dev"

# Pi 5 heeft extra gpiod versie nodig (bookworm)
if [ "$PI_VERSION" -ge 5 ]; then
  PACKAGES="$PACKAGES python3-libgpiod gpiod"
fi

# Pi 4-specifiek: wiringPi alternatief via lgpio op bookworm
if [ "$OS_CODENAME" = "bookworm" ]; then
  PACKAGES="$PACKAGES liblgpio-dev"
fi

sudo apt-get install -y $PACKAGES
log "Pakketten geïnstalleerd."

# =============================================================================
# STAP 2: ftdi_sio kernelmodule blokkeren
# =============================================================================
echo ""
title "STAP 2: ftdi_sio kernelmodule blokkeren..."

BLACKLIST_FILE="/etc/modprobe.d/radioberry-ftdi.conf"
if [ ! -f "$BLACKLIST_FILE" ]; then
  sudo tee "$BLACKLIST_FILE" > /dev/null << 'EOF'
# Radioberry Juice Board - blokkeer standaard FTDI seriele driver
# zodat libftdi directe USB toegang heeft tot de FT2232H
blacklist ftdi_sio
blacklist usbserial
EOF
  log "Blacklist aangemaakt: $BLACKLIST_FILE"
else
  log "Blacklist bestaat al."
fi

# Verwijder de module als geladen
if lsmod | grep -q ftdi_sio; then
  sudo rmmod ftdi_sio 2>/dev/null || warn "Kon ftdi_sio niet verwijderen, herstart vereist."
fi

# =============================================================================
# STAP 3: udev regels voor FT2232H (niet-root toegang)
# =============================================================================
echo ""
title "STAP 3: udev regels instellen voor FT2232H..."

UDEV_FILE="/etc/udev/rules.d/99-radioberry-ftdi.rules"
sudo tee "$UDEV_FILE" > /dev/null << 'EOF'
# Radioberry Juice Board - FT2232H (FTDI 0403:6010)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", GROUP="plugdev", MODE="0664", SYMLINK+="radioberry"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", GROUP="plugdev", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6011", GROUP="plugdev", MODE="0664"
EOF

log "udev regels geschreven: $UDEV_FILE"

# Gebruiker in plugdev groep
if ! groups "$USER" | grep -q plugdev; then
  sudo usermod -a -G plugdev "$USER"
  log "Gebruiker $USER toegevoegd aan plugdev."
else
  log "Gebruiker $USER is al lid van plugdev."
fi

# Gebruiker ook in gpio groep (Pi specifiek)
if ! groups "$USER" | grep -q gpio; then
  sudo usermod -a -G gpio "$USER"
  log "Gebruiker $USER toegevoegd aan gpio groep."
fi

sudo udevadm control --reload-rules
sudo udevadm trigger
log "udev regels herladen."

# =============================================================================
# STAP 4: Radioberry Juice firmware downloaden en bouwen
# =============================================================================
echo ""
title "STAP 4: Radioberry Juice firmware downloaden en bouwen..."

INSTALL_DIR="$HOME/radioberry"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if [ ! -d "Radioberry-2.x" ]; then
  info "Repository klonen..."
  git clone https://github.com/pa3gsb/Radioberry-2.x.git
  log "Repository gekloneerd."
else
  info "Repository bestaat al, updaten..."
  cd Radioberry-2.x && git pull && cd ..
  log "Repository geüpdatet."
fi

cd Radioberry-2.x/juice/firmware

# linux-Makefile is bedoeld voor RPi en Linux
if [ ! -f "linux-Makefile" ]; then
  error "linux-Makefile niet gevonden in juice/firmware. Controleer de repository."
fi

cp linux-Makefile Makefile

info "Firmware bouwen voor Pi $PI_VERSION..."
make clean 2>/dev/null || true
make

if [ -f "radioberry-juice" ]; then
  log "Firmware gebouwd: radioberry-juice"
else
  error "Build mislukt. Controleer de foutmeldingen hierboven."
fi

# =============================================================================
# STAP 5: Firmware en gateware installeren
# =============================================================================
echo ""
title "STAP 5: Firmware en gateware installeren..."

sudo cp radioberry-juice /usr/local/bin/radioberry-juice
sudo chmod +x /usr/local/bin/radioberry-juice
log "Firmware: /usr/local/bin/radioberry-juice"

# Gateware zoeken
RBF_FILE=$(find "$INSTALL_DIR/Radioberry-2.x" -name "radioberry.rbf" | head -1)
sudo mkdir -p /etc/radioberry

if [ -n "$RBF_FILE" ]; then
  sudo cp "$RBF_FILE" /etc/radioberry/radioberry.rbf
  log "Gateware: /etc/radioberry/radioberry.rbf"
else
  warn "Geen radioberry.rbf gevonden. Download handmatig:"
  warn "  https://github.com/pa3gsb/Radioberry-2.x/tree/master/juice/firmware"
  warn "Plaats het bestand in /etc/radioberry/radioberry.rbf"
fi

# =============================================================================
# STAP 6: SPI / I2C inschakelen (Pi-specifiek, voor preamp board)
# =============================================================================
echo ""
title "STAP 6: SPI en I2C interfaces inschakelen (voor preamp board)..."

# SPI inschakelen
if ! grep -q "^dtparam=spi=on" /boot/firmware/config.txt 2>/dev/null && \
   ! grep -q "^dtparam=spi=on" /boot/config.txt 2>/dev/null; then
  BOOT_CONFIG="/boot/firmware/config.txt"
  [ ! -f "$BOOT_CONFIG" ] && BOOT_CONFIG="/boot/config.txt"
  echo "dtparam=spi=on" | sudo tee -a "$BOOT_CONFIG" > /dev/null
  log "SPI ingeschakeld in $BOOT_CONFIG"
else
  log "SPI was al ingeschakeld."
fi

# I2C inschakelen
if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null && \
   ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt 2>/dev/null; then
  BOOT_CONFIG="/boot/firmware/config.txt"
  [ ! -f "$BOOT_CONFIG" ] && BOOT_CONFIG="/boot/config.txt"
  echo "dtparam=i2c_arm=on" | sudo tee -a "$BOOT_CONFIG" > /dev/null
  log "I2C ingeschakeld in $BOOT_CONFIG"
else
  log "I2C was al ingeschakeld."
fi

sudo apt-get install -y -qq i2c-tools
if ! groups "$USER" | grep -q i2c; then
  sudo usermod -a -G i2c "$USER"
  log "Gebruiker $USER toegevoegd aan i2c groep."
fi

# =============================================================================
# STAP 7: Systemd service aanmaken
# =============================================================================
echo ""
title "STAP 7: Systemd autostart service aanmaken..."

SERVICE_FILE="/etc/systemd/system/radioberry-juice.service"
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Radioberry Juice Board Firmware (PA3GSB)
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=/etc/radioberry
ExecStartPre=/bin/sleep 3
ExecStart=/usr/local/bin/radioberry-juice
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
log "Systemd service aangemaakt."
info "Autostart inschakelen: sudo systemctl enable radioberry-juice"
info "Nu starten:            sudo systemctl start radioberry-juice"

# =============================================================================
# STAP 8: Optioneel SDR software installeren
# =============================================================================
echo ""
title "STAP 8: SDR software installeren (optioneel)..."

echo ""
echo "Welke SDR software wil je installeren?"
echo "  1) piHPSDR  (aanbevolen voor RPi, ondersteunt Radioberry native)"
echo "  2) Quisk    (Python SDR, ondersteunt OpenHPSDR Protocol-1)"
echo "  3) Beide"
echo "  4) Overslaan"
echo ""
read -rp "Keuze [1/2/3/4]: " SDR_CHOICE

install_pihpsdr() {
  info "piHPSDR installeren..."
  sudo apt-get install -y -qq libcairo2-dev libjpeg-dev libglib2.0-dev \
    libpango1.0-dev libatk1.0-dev libsoup2.4-dev portaudio19-dev \
    libwdsp-dev || true

  cd "$INSTALL_DIR"
  if [ ! -d "pihpsdr" ]; then
    git clone https://github.com/dl1ycf/pihpsdr.git
  else
    cd pihpsdr && git pull && cd ..
  fi
  cd pihpsdr
  make -j$(nproc)
  sudo cp pihpsdr /usr/local/bin/pihpsdr
  log "piHPSDR geïnstalleerd: /usr/local/bin/pihpsdr"
}

install_quisk() {
  info "Quisk installeren..."
  sudo apt-get install -y -qq python3-pip python3-pyaudio python3-numpy python3-scipy
  pip3 install quisk --break-system-packages 2>/dev/null || pip3 install quisk
  log "Quisk geïnstalleerd."
}

case "$SDR_CHOICE" in
  1) install_pihpsdr ;;
  2) install_quisk ;;
  3) install_pihpsdr; install_quisk ;;
  4) info "SDR software installatie overgeslagen." ;;
  *) info "Ongeldige keuze, overgeslagen." ;;
esac

# =============================================================================
# SAMENVATTING
# =============================================================================
echo ""
echo "============================================================"
echo -e "  ${GREEN}Installatie voltooid!${NC}"
echo "  Raspberry Pi $PI_VERSION - $OS_CODENAME"
echo "============================================================"
echo ""
echo "  Hardware aansluiting:"
echo "    - Radioberry 2.x kaart op Juice Board gestoken"
echo "    - Juice Board via USB-A kabel aan RPi verbonden"
echo "    - Voeding Juice Board: 12V DC (eigen voeding!)"
echo "    - Optioneel: preamp board op Radioberry (I2C pin 15/16)"
echo ""
echo "  BELANGRIJK - Herstart vereist!"
echo "    sudo reboot"
echo ""
echo "  Na herstart:"
echo "    lsusb | grep FTDI              # Juice board zichtbaar? (0403:6010)"
echo "    radioberry-juice               # Firmware starten (laadt FPGA gateware)"
echo "    pihpsdr                        # SDR software starten (indien geïnstalleerd)"
echo ""
echo "  Autostart inschakelen:"
echo "    sudo systemctl enable radioberry-juice"
echo "    sudo systemctl start radioberry-juice"
echo "    sudo systemctl status radioberry-juice"
echo ""
echo "  I2C preamp board controleren:"
echo "    i2cdetect -y 1"
echo ""
echo "  Pi $PI_VERSION specifieke opmerkingen:"
if [ "$PI_VERSION" -eq 5 ]; then
echo "    - Pi 5 gebruikt RP1 I/O controller (andere GPIO pinout dan Pi 4)"
echo "    - USB 3.0 poorten geven hogere bandbreedte voor IQ streaming"
echo "    - Gebruik bij voorkeur de USB 2.0 poort voor de Juice Board"
echo "      (FT2232H is USB 2.0 High Speed, 480 Mbps)"
elif [ "$PI_VERSION" -eq 4 ]; then
echo "    - Pi 4 USB 3.0 poorten volledig ondersteund voor IQ streaming"
echo "    - Bij thermische problemen: actieve koeling aanbevolen"
fi
echo ""
echo "  Nuttige links:"
echo "    Website:  https://www.pa3gsb.nl"
echo "    GitHub:   https://github.com/pa3gsb/Radioberry-2.x"
echo "    Wiki:     https://github.com/pa3gsb/Radioberry-2.x/wiki"
echo "    Forum:    https://groups.google.com/g/radioberry"
echo ""
echo "  73 de PA3GSB / Script gegenereerd met Claude"
echo "============================================================"
echo ""
read -rp "Nu herstarten? [j/N]: " REBOOT_NOW
if [[ "$REBOOT_NOW" =~ ^[jJ]$ ]]; then
  sudo reboot
fi
