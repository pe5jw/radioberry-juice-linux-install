#!/bin/bash
# =============================================================================
# Radioberry 2.x + Juice Board - Linux USB Install Script
# =============================================================================
# Verbindt de Radioberry via het Juice Board (FT2232H) via USB met een Linux PC.
# Gebaseerd op het werk van Johan PA3GSB - https://www.pa3gsb.nl
# GitHub: https://github.com/pa3gsb/Radioberry-2.x
#
# Wat dit script doet:
#   1. Vereiste pakketten installeren (libftdi, build tools)
#   2. ftdi_sio kernelmodule blokkeren (zodat libftdi directe USB toegang heeft)
#   3. udev regels instellen voor niet-root toegang tot FT2232H
#   4. Radioberry Juice firmware downloaden en bouwen
#   5. Gateware (.rbf) bestand installeren
#   6. Verbinding testen
#
# Ondersteunde distro's: Ubuntu 20.04/22.04/24.04, Debian 11/12
# Hardware: Radioberry 2.x + Juice Board (FT2232H) via USB
# =============================================================================

set -e

# --- Kleuren voor output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WAARSCHUWING]${NC} $1"; }
error()  { echo -e "${RED}[FOUT]${NC} $1"; exit 1; }
info()   { echo -e "${BLUE}[INFO]${NC} $1"; }

echo ""
echo "============================================================"
echo "  Radioberry 2.x Juice Board - Linux USB Installatie"
echo "  PA3GSB - https://www.pa3gsb.nl"
echo "============================================================"
echo ""

# --- Root check ---
if [ "$EUID" -eq 0 ]; then
  error "Voer dit script NIET uit als root. Gebruik een normale gebruiker (sudo wordt waar nodig gevraagd)."
fi

# --- Distributiebepaling ---
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO=$ID
  info "Gedetecteerde distro: $PRETTY_NAME"
else
  error "Kan Linux-distributie niet bepalen. /etc/os-release niet gevonden."
fi

# =============================================================================
# STAP 1: Vereiste pakketten installeren
# =============================================================================
echo ""
info "STAP 1: Vereiste pakketten installeren..."

PACKAGES="build-essential git libftdi1 libftdi1-dev libusb-1.0-0 libusb-1.0-0-dev pkg-config cmake wget unzip"

case "$DISTRO" in
  ubuntu|debian|raspbian)
    sudo apt-get update -qq
    sudo apt-get install -y $PACKAGES
    ;;
  fedora)
    sudo dnf install -y gcc gcc-c++ make git libftdi-devel libusb1-devel cmake wget unzip
    ;;
  arch|manjaro)
    sudo pacman -Sy --noconfirm base-devel git libftdi libusb cmake wget unzip
    ;;
  *)
    warn "Onbekende distro '$DISTRO'. Probeer Ubuntu/Debian pakketten..."
    sudo apt-get update -qq && sudo apt-get install -y $PACKAGES || \
      error "Pakketinstallatie mislukt. Installeer handmatig: $PACKAGES"
    ;;
esac
log "Pakketten geïnstalleerd."

# =============================================================================
# STAP 2: ftdi_sio kernelmodule blokkeren
# =============================================================================
# De standaard ftdi_sio driver claimt de FT2232H. Libftdi heeft directe
# USB toegang nodig (via libusb), dus de kernelmodule moet worden geblokkeerd.
echo ""
info "STAP 2: ftdi_sio kernelmodule blokkeren..."

BLACKLIST_FILE="/etc/modprobe.d/radioberry-ftdi.conf"
if [ ! -f "$BLACKLIST_FILE" ]; then
  echo "blacklist ftdi_sio" | sudo tee "$BLACKLIST_FILE" > /dev/null
  echo "blacklist usbserial" | sudo tee -a "$BLACKLIST_FILE" > /dev/null
  log "ftdi_sio geblokkeerd in $BLACKLIST_FILE"
else
  log "ftdi_sio blacklist bestaat al."
fi

# Verwijder de module als deze al geladen is
if lsmod | grep -q ftdi_sio; then
  sudo rmmod ftdi_sio 2>/dev/null || warn "Kon ftdi_sio niet verwijderen (misschien in gebruik). Herstart aanbevolen na installatie."
  log "ftdi_sio module verwijderd."
fi

# =============================================================================
# STAP 3: udev regels instellen voor FT2232H (niet-root toegang)
# =============================================================================
echo ""
info "STAP 3: udev regels instellen voor FT2232H..."

UDEV_FILE="/etc/udev/rules.d/99-radioberry-ftdi.rules"
sudo tee "$UDEV_FILE" > /dev/null << 'EOF'
# Radioberry Juice Board - FT2232H USB toegangsregels
# FTDI Vendor ID: 0403, FT2232H Product ID: 6010
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6010", GROUP="plugdev", MODE="0664", SYMLINK+="radioberry"
# Alternatieve product ID's (custom EEPROM configuratie)
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6001", GROUP="plugdev", MODE="0664"
SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6011", GROUP="plugdev", MODE="0664"
EOF

log "udev regels geschreven naar $UDEV_FILE"

# Huidige gebruiker toevoegen aan plugdev groep
if ! groups "$USER" | grep -q plugdev; then
  sudo usermod -a -G plugdev "$USER"
  log "Gebruiker $USER toegevoegd aan plugdev groep."
  warn "Je moet opnieuw inloggen om groepslidmaatschap te activeren."
else
  log "Gebruiker $USER is al lid van plugdev."
fi

# udev regels opnieuw laden
sudo udevadm control --reload-rules
sudo udevadm trigger
log "udev regels herladen."

# =============================================================================
# STAP 4: Radioberry Juice firmware downloaden en bouwen
# =============================================================================
echo ""
info "STAP 4: Radioberry Juice firmware downloaden en bouwen..."

INSTALL_DIR="$HOME/radioberry-juice"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Kloon de Radioberry 2.x repository
if [ ! -d "Radioberry-2.x" ]; then
  info "Repository klonen van GitHub..."
  git clone https://github.com/pa3gsb/Radioberry-2.x.git
  log "Repository gekloneerd."
else
  info "Repository bestaat al. Updaten..."
  cd Radioberry-2.x && git pull && cd ..
  log "Repository geüpdatet."
fi

cd Radioberry-2.x/juice/firmware

# Controleer of linux-Makefile aanwezig is
if [ ! -f "linux-Makefile" ]; then
  error "linux-Makefile niet gevonden in juice/firmware. Controleer de repository structuur."
fi

# Kopieer linux Makefile naar Makefile
cp linux-Makefile Makefile

info "Firmware bouwen..."
make clean 2>/dev/null || true
make

if [ -f "radioberry-juice" ]; then
  log "Firmware succesvol gebouwd: radioberry-juice"
else
  error "Build mislukt. Controleer de foutmeldingen hierboven."
fi

# =============================================================================
# STAP 5: Firmware en gateware installeren
# =============================================================================
echo ""
info "STAP 5: Firmware en gateware installeren..."

# Firmware binary installeren
sudo cp radioberry-juice /usr/local/bin/radioberry-juice
sudo chmod +x /usr/local/bin/radioberry-juice
log "Firmware geïnstalleerd in /usr/local/bin/radioberry-juice"

# Gateware (.rbf) zoeken en installeren
RBF_FILE=$(find "$INSTALL_DIR/Radioberry-2.x" -name "radioberry.rbf" | head -1)
if [ -n "$RBF_FILE" ]; then
  sudo mkdir -p /etc/radioberry
  sudo cp "$RBF_FILE" /etc/radioberry/radioberry.rbf
  log "Gateware geïnstalleerd: /etc/radioberry/radioberry.rbf"
else
  warn "Geen radioberry.rbf gateware gevonden. Download handmatig van:"
  warn "  https://github.com/pa3gsb/Radioberry-2.x/tree/master/juice/firmware"
  warn "en plaats het in /etc/radioberry/radioberry.rbf"
fi

# =============================================================================
# STAP 6: Systemd service aanmaken (optioneel - autostart)
# =============================================================================
echo ""
info "STAP 6: Systemd service aanmaken voor autostart..."

SERVICE_FILE="/etc/systemd/system/radioberry-juice.service"
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Radioberry Juice Board Firmware
After=network.target

[Service]
Type=simple
User=$USER
ExecStartPre=/bin/sleep 2
ExecStart=/usr/local/bin/radioberry-juice
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
log "Systemd service aangemaakt: radioberry-juice.service"
info "Autostart inschakelen: sudo systemctl enable radioberry-juice"
info "Handmatig starten:     sudo systemctl start radioberry-juice"

# =============================================================================
# STAP 7: Verificatie
# =============================================================================
echo ""
info "STAP 7: Verbinding verificeren..."

info "Controleer of Juice Board aangesloten is via USB en voer dan uit:"
echo ""
echo "  lsusb | grep FTDI          # Juice board tonen (0403:6010)"
echo "  /usr/local/bin/radioberry-juice  # Firmware starten en FPGA laden"
echo ""
info "Bij 'permission denied': herstart je sessie of log opnieuw in (plugdev groep)."

# =============================================================================
# SAMENVATTING
# =============================================================================
echo ""
echo "============================================================"
echo -e "  ${GREEN}Installatie voltooid!${NC}"
echo "============================================================"
echo ""
echo "  Hardware setup:"
echo "    - Radioberry 2.x kaart op het Juice Board gestoken"
echo "    - Juice Board via USB kabel aan PC verbonden"
echo "    - Voeding: 12V op Juice Board (NIET via de Pi connector)"
echo ""
echo "  Volgende stappen:"
echo "    1. Herstart je systeem (of log opnieuw in voor plugdev groep)"
echo "    2. Sluit de Juice Board aan via USB"
echo "    3. Controleer: lsusb | grep FTDI"
echo "    4. Start firmware: radioberry-juice"
echo "    5. Start SDR software (Quisk, SparkSDR, Thetis, piHPSDR)"
echo "       en gebruik het OpenHPSDR Protocol-1 (discovery via UDP)"
echo ""
echo "  Nuttige links:"
echo "    Website:  https://www.pa3gsb.nl"
echo "    GitHub:   https://github.com/pa3gsb/Radioberry-2.x"
echo "    Wiki:     https://github.com/pa3gsb/Radioberry-2.x/wiki"
echo "    Forum:    https://groups.google.com/g/radioberry"
echo ""
echo "  73 de PA3GSB / Installatiescript gegenereerd met Claude"
echo "============================================================"
