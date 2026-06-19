#!/bin/bash
# =============================================================================
# Radioberry 2.x + Juice Board - Raspberry Pi 4 / Pi 5 Install Script
# =============================================================================
# Verbindt de Radioberry via het Juice Board (FT2232H) via USB met een RPi4/5.
# Gebaseerd op het werk van Johan PA3GSB - https://www.pa3gsb.nl
# GitHub: https://github.com/pa3gsb/Radioberry-2.x
#
# Ondersteund:
#   Raspberry Pi 4  - Raspberry Pi OS Bookworm (Debian 12) of Trixie (Debian 13)
#   Raspberry Pi 5  - Raspberry Pi OS Bookworm (Debian 12) of Trixie (Debian 13)
#
# Pi OS versies:
#   Bookworm (Debian 12) - uitgebracht okt 2023, laatste update mei 2025
#   Trixie   (Debian 13) - uitgebracht okt 2025, huidig standaard [aanbevolen]
#
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
# Pi model en OS versie detecteren
# =============================================================================
detect_pi_model() {
  if [ ! -f /proc/device-tree/model ]; then
    error "Geen Raspberry Pi gedetecteerd. Dit script is alleen voor RPi 4/5."
  fi
  PI_MODEL=$(cat /proc/device-tree/model)
  info "Hardware: $PI_MODEL"

  if echo "$PI_MODEL" | grep -q "Raspberry Pi 5"; then
    PI_VERSION=5
    log "Raspberry Pi 5 gedetecteerd."
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 4"; then
    PI_VERSION=4
    log "Raspberry Pi 4 gedetecteerd."
  elif echo "$PI_MODEL" | grep -q "Raspberry Pi 3"; then
    PI_VERSION=3
    warn "Raspberry Pi 3 gedetecteerd - niet officieel ondersteund, doorgaan op eigen risico."
  else
    error "Onbekend Pi model: $PI_MODEL. Dit script ondersteunt Pi 4 en Pi 5."
  fi
}

detect_os() {
  if [ ! -f /etc/os-release ]; then
    error "Kan OS niet bepalen."
  fi
  . /etc/os-release
  OS_CODENAME=${VERSION_CODENAME:-unknown}
  OS_VERSION=${VERSION_ID:-unknown}
  info "OS: $PRETTY_NAME"

  case "$OS_CODENAME" in
    trixie)
      log "Raspberry Pi OS Trixie (Debian 13) - huidig aanbevolen, volledig ondersteund." ;;
    bookworm)
      log "Raspberry Pi OS Bookworm (Debian 12) - ondersteund." ;;
    bullseye)
      warn "Raspberry Pi OS Bullseye (Debian 11) - verouderd. Upgrade naar Trixie aanbevolen." ;;
    buster)
      error "Raspberry Pi OS Buster (Debian 10) is EOL en niet ondersteund. Installeer Trixie." ;;
    *)
      warn "Onbekende OS versie '$OS_CODENAME' - doorgaan op eigen risico." ;;
  esac
}

detect_pi_model
detect_os

# Bepaal boot config locatie (verschilt per OS versie)
if [ -f /boot/firmware/config.txt ]; then
  BOOT_CONFIG="/boot/firmware/config.txt"   # Bookworm en Trixie
else
  BOOT_CONFIG="/boot/config.txt"            # Bullseye en ouder
fi
info "Boot config: $BOOT_CONFIG"

# =============================================================================
# STAP 1: Systeem updaten en pakketten installeren
# =============================================================================
echo ""
title "STAP 1: Systeem updaten en pakketten installeren..."

sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# Basis pakketten
PACKAGES="build-essential git cmake pkg-config wget unzip \
  libftdi1 libftdi1-dev \
  libusb-1.0-0 libusb-1.0-0-dev \
  libfftw3-dev \
  libasound2-dev \
  libpulse-dev \
  libgtk-3-dev \
  i2c-tools"

# Trixie (Debian 13) specifiek: lgpio vervangt wiringPi volledig
# Bookworm had lgpio al, Trixie is de standaard
case "$OS_CODENAME" in
  trixie)
    PACKAGES="$PACKAGES libgpiod-dev gpiod liblgpio-dev python3-libgpiod"
    ;;
  bookworm)
    PACKAGES="$PACKAGES libgpiod-dev gpiod liblgpio-dev python3-libgpiod"
    ;;
  bullseye)
    PACKAGES="$PACKAGES libgpiod-dev gpiod"
    # wiringPi is deprecated op bullseye maar soms nog aanwezig
    ;;
esac

sudo apt-get install -y $PACKAGES
log "Pakketten geinstalleerd."

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

if ! groups "$USER" | grep -q plugdev; then
  sudo usermod -a -G plugdev "$USER"
  log "Gebruiker $USER toegevoegd aan plugdev."
else
  log "Gebruiker $USER is al lid van plugdev."
fi

if ! groups "$USER" | grep -q gpio; then
  sudo usermod -a -G gpio "$USER"
  log "Gebruiker $USER toegevoegd aan gpio groep."
fi

if ! groups "$USER" | grep -q i2c; then
  sudo usermod -a -G i2c "$USER"
  log "Gebruiker $USER toegevoegd aan i2c groep."
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
  log "Repository geupdate."
fi

cd Radioberry-2.x/juice/firmware

if [ ! -f "linux-Makefile" ]; then
  error "linux-Makefile niet gevonden in juice/firmware. Controleer de repository."
fi

cp linux-Makefile Makefile

info "Firmware bouwen voor Pi $PI_VERSION ($OS_CODENAME)..."
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
# STAP 6: SPI / I2C inschakelen
# =============================================================================
echo ""
title "STAP 6: SPI en I2C inschakelen (voor preamp board)..."

# SPI
if ! grep -q "^dtparam=spi=on" "$BOOT_CONFIG" 2>/dev/null; then
  echo "dtparam=spi=on" | sudo tee -a "$BOOT_CONFIG" > /dev/null
  log "SPI ingeschakeld in $BOOT_CONFIG"
else
  log "SPI was al ingeschakeld."
fi

# I2C
if ! grep -q "^dtparam=i2c_arm=on" "$BOOT_CONFIG" 2>/dev/null; then
  echo "dtparam=i2c_arm=on" | sudo tee -a "$BOOT_CONFIG" > /dev/null
  log "I2C ingeschakeld in $BOOT_CONFIG"
else
  log "I2C was al ingeschakeld."
fi

# Pi 5 specifiek: I2C bus op Trixie via RP1 controller
if [ "$PI_VERSION" -eq 5 ] && [ "$OS_CODENAME" = "trixie" ]; then
  info "Pi 5 Trixie: controleer of i2c-dev module geladen wordt..."
  if ! grep -q "i2c-dev" /etc/modules 2>/dev/null; then
    echo "i2c-dev" | sudo tee -a /etc/modules > /dev/null
    log "i2c-dev toegevoegd aan /etc/modules"
  fi
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
echo "  1) piHPSDR  (aanbevolen voor RPi, native Radioberry support)"
echo "  2) Quisk    (Python SDR, OpenHPSDR Protocol-1)"
echo "  3) Beide"
echo "  4) Overslaan"
echo ""
read -rp "Keuze [1/2/3/4]: " SDR_CHOICE

install_pihpsdr() {
  info "piHPSDR installeren..."
  PIHPSDR_DEPS="libcairo2-dev libjpeg-dev libglib2.0-dev \
    libpango1.0-dev libatk1.0-dev portaudio19-dev"

  # libasound2-dev naam verschilt op trixie
  if [ "$OS_CODENAME" = "trixie" ]; then
    PIHPSDR_DEPS="$PIHPSDR_DEPS libasound2-dev"
  else
    PIHPSDR_DEPS="$PIHPSDR_DEPS libasound2-dev"
  fi

  sudo apt-get install -y -qq $PIHPSDR_DEPS || true

  cd "$INSTALL_DIR"
  if [ ! -d "pihpsdr" ]; then
    git clone https://github.com/dl1ycf/pihpsdr.git
  else
    cd pihpsdr && git pull && cd ..
  fi
  cd pihpsdr
  make -j$(nproc)
  sudo cp pihpsdr /usr/local/bin/pihpsdr
  log "piHPSDR geinstalleerd: /usr/local/bin/pihpsdr"
}

install_quisk() {
  info "Quisk installeren..."
  sudo apt-get install -y -qq python3-pip python3-pyaudio python3-numpy python3-scipy
  pip3 install quisk --break-system-packages 2>/dev/null || pip3 install quisk
  log "Quisk geinstalleerd."
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
echo "  Hardware : Raspberry Pi $PI_VERSION"
echo "  OS       : $PRETTY_NAME"
echo "============================================================"
echo ""
echo "  Hardware aansluiting:"
echo "    - Radioberry 2.x kaart op Juice Board gestoken"
echo "    - Juice Board via USB-A kabel aan RPi verbonden"
echo "    - Voeding Juice Board: 12V DC (eigen voeding!)"
echo "    - Optioneel: preamp board op Radioberry (I2C)"
echo ""
echo "  HERSTART VEREIST voor:"
echo "    - Groepswijzigingen (plugdev, gpio, i2c)"
echo "    - SPI/I2C activering"
echo "    - ftdi_sio blacklist"
echo ""
echo "  sudo reboot"
echo ""
echo "  Na herstart:"
echo "    lsusb | grep FTDI              # Juice board? (0403:6010)"
echo "    radioberry-juice               # FPGA laden en starten"
echo "    i2cdetect -y 1                 # Preamp board controleren"
echo ""
echo "  Autostart:"
echo "    sudo systemctl enable radioberry-juice"
echo "    sudo systemctl start radioberry-juice"
echo "    sudo systemctl status radioberry-juice"
echo ""

if [ "$PI_VERSION" -eq 5 ]; then
  echo "  Pi 5 opmerkingen:"
  echo "    - USB 2.0 poort aanbevolen voor Juice Board (FT2232H is USB 2.0)"
  echo "    - Pi 5 gebruikt RP1 I/O controller (eigen GPIO driver, lgpio)"
  echo "    - Trixie OS is de aanbevolen versie voor Pi 5"
elif [ "$PI_VERSION" -eq 4 ]; then
  echo "  Pi 4 opmerkingen:"
  echo "    - Alle USB 3.0 poorten werken prima voor de Juice Board"
  echo "    - Bij hoge CPU load: actieve koeling aanbevolen"
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
