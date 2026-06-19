# Radioberry 2.x — Juice Board Linux Install Scripts

> Install scripts voor de **Radioberry 2.x** SDR transceiver met het **Juice Board (FT2232H)** via USB op Linux en Raspberry Pi.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Raspberry%20Pi-blue)]()
[![Tested](https://img.shields.io/badge/tested-Ubuntu%2024.04%20%7C%2026.04%20%7C%20RPi%20OS%20Trixie-green)]()

Gebaseerd op het open source project van Johan PA3GSB:
🌐 [pa3gsb.nl](https://www.pa3gsb.nl) · 📦 [Radioberry-2.x GitHub](https://github.com/pa3gsb/Radioberry-2.x) · 💬 [Forum](https://groups.google.com/g/radioberry)

---

## Wat is de Radioberry?

De Radioberry is een SDR transceiver als Raspberry Pi hat, gebaseerd op de **Analog Devices AD9866** (0–30 MHz, 12-bit DDC/DUC) en een **Intel Cyclone 10LP FPGA**.

Het **Juice Board** voegt een **FTDI FT2232H** USB-interface toe, waardoor de Radioberry direct via USB op een Linux PC of Raspberry Pi aangesloten kan worden — zonder dat een RPi als vaste host vereist is.

```
┌─────────────────────┐
│  Radioberry 2.x     │  ← AD9866 + Cyclone 10LP FPGA
│  (SDR kaart)        │
└────────┬────────────┘
         │ 40-pin header
┌────────┴────────────┐
│  Juice Board        │  ← FTDI FT2232H (USB 2.0 HS)
│  (USB interface)    │     + 12V voeding
└────────┬────────────┘
         │ USB-A kabel
┌────────┴────────────┐
│  Linux PC / RPi 4/5 │  ← Dit script installeert alles
└────────┬────────────┘
         │ UDP / OpenHPSDR Protocol-1
┌────────┴────────────┐
│  SDR Software       │  ← piHPSDR / Quisk / SparkSDR
└─────────────────────┘
```

---

## Scripts

### 🖥️ `radioberry_juice_linux_install.sh` — Ubuntu / Debian PC

| OS | Versie | Status |
|---|---|---|
| Ubuntu | 26.04 LTS Resolute Raccoon | ✅ Ondersteund |
| Ubuntu | 25.04 Plucky Puffin | ✅ Ondersteund |
| Ubuntu | 24.04 LTS Noble Numbat | ✅ Aanbevolen |
| Ubuntu | 22.04 LTS Jammy Jellyfish | ✅ Ondersteund |
| Ubuntu | 20.04 LTS Focal | ⚠️ EOL apr 2025 |
| Debian | 13 Trixie | ✅ Ondersteund |
| Debian | 12 Bookworm | ✅ Ondersteund |

**Wat het doet:**
- OS versie detecteren en waarschuwen bij verouderde versies
- Installeert `libftdi1`, `build-essential`, `git`, `cmake`, `libusb`
- Blokkeert de `ftdi_sio` kernelmodule (zodat libftdi directe USB-toegang heeft)
- Maakt udev regels aan voor niet-root toegang (FTDI `0403:6010`)
- Kloont de Radioberry-2.x repo en bouwt de Juice firmware
- Installeert firmware → `/usr/local/bin/radioberry-juice`
- Installeert gateware → `/etc/radioberry/radioberry.rbf`
- Maakt systemd service aan voor autostart

**Gebruik:**
```bash
chmod +x radioberry_juice_linux_install.sh
./radioberry_juice_linux_install.sh
```

**Of direct van GitHub:**
```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/radioberry-juice-linux-install/main/radioberry_juice_linux_install.sh
chmod +x radioberry_juice_linux_install.sh && ./radioberry_juice_linux_install.sh
```

---

### 🍓 `radioberry_juice_rpi_install.sh` — Raspberry Pi 4 / Pi 5

| Hardware | OS | Status |
|---|---|---|
| Raspberry Pi 5 | Pi OS Trixie (Debian 13) | ✅ Aanbevolen |
| Raspberry Pi 5 | Pi OS Bookworm (Debian 12) | ✅ Ondersteund |
| Raspberry Pi 4 | Pi OS Trixie (Debian 13) | ✅ Ondersteund |
| Raspberry Pi 4 | Pi OS Bookworm (Debian 12) | ✅ Ondersteund |
| Raspberry Pi 4 | Pi OS Bullseye (Debian 11) | ⚠️ Verouderd |

**Wat het doet:**
- Pi model automatisch detecteren (Pi 4 / Pi 5)
- OS versie controleren (Bookworm / Trixie) en juiste libraries kiezen
- Installeert alle pakketten inclusief GPIO/I2C/SPI libraries
- Blokkeert `ftdi_sio`, maakt udev regels aan
- Schakelt SPI en I2C in via `config.txt` (voor preamp board)
- Pi 5 Trixie: laadt `i2c-dev` module via `/etc/modules`
- Bouwt en installeert de Juice firmware + gateware
- Maakt systemd service aan voor autostart
- Optioneel: installeert **piHPSDR** en/of **Quisk** via keuzemenu

**Gebruik:**
```bash
chmod +x radioberry_juice_rpi_install.sh
./radioberry_juice_rpi_install.sh
```

**Of direct van GitHub:**
```bash
wget https://raw.githubusercontent.com/YOUR_USERNAME/radioberry-juice-linux-install/main/radioberry_juice_rpi_install.sh
chmod +x radioberry_juice_rpi_install.sh && ./radioberry_juice_rpi_install.sh
```

---

## Hardware benodigdheden

| Onderdeel | Omschrijving |
|---|---|
| Radioberry 2.x | SDR kaart — AD9866 + Intel Cyclone 10LP FPGA |
| Juice Board | FT2232H USB interface board |
| USB-A kabel | Juice Board → PC of RPi |
| 12V DC voeding | Voor Juice Board (eigen adapter, niet via GPIO!) |
| HF antenne | 50 Ω, bereik 0–30 MHz |
| Preamp board *(opt.)* | 5W versterker + I2C LPF sturing |

---

## Aansluitvolgorde

1. Steek de Radioberry 2.x kaart op het Juice Board (40-pin header)
2. Verbind 12V voeding met het Juice Board
3. Verbind USB kabel: Juice Board → PC of RPi
4. Voer het installatiescript uit
5. Herstart het systeem
6. Controleer USB: `lsusb | grep FTDI` → moet `0403:6010` tonen
7. Start firmware: `radioberry-juice`
8. Start SDR software → OpenHPSDR Protocol-1 UDP discovery

---

## SDR Software (OpenHPSDR Protocol-1)

| Software | Platform | Link |
|---|---|---|
| piHPSDR | Linux / RPi | [github.com/dl1ycf/pihpsdr](https://github.com/dl1ycf/pihpsdr) |
| Quisk | Linux / Windows / Mac | [james.ahlstrom.name/quisk](https://james.ahlstrom.name/quisk/) |
| SparkSDR | Windows / Linux | [sparksdr.com](https://www.sparksdr.com/) |
| Thetis | Windows | [github.com/TAPR/OpenHPSDR-Thetis](https://github.com/TAPR/OpenHPSDR-Thetis) |
| linHPSDR | Linux | [github.com/LightHFRadio/linHPSDR](https://github.com/LightHFRadio/linHPSDR) |

---

## Prestaties (Juice Board / FT2232H)

| Meting | Waarde |
|---|---|
| Interface | FT2232H FT245 Sync FIFO |
| Max USB bandbreedte | 480 Mbps (USB 2.0 High Speed) |
| Gemeten op RPi 4 | ~320 Mbps |
| Gemeten op Linux laptop | ~386 Mbps |
| Gelijktijdige ontvangers | ~6× bij 384 kHz sample rate |

---

## Probleemoplossing

**`lsusb` toont geen FTDI device:**
- Controleer USB kabel en 12V voeding op Juice Board
- Probeer een andere USB poort

**Permission denied bij starten firmware:**
```bash
# Herstart sessie of voer uit:
sudo usermod -a -G plugdev $USER
# Log opnieuw in
```

**ftdi_sio module laadt toch:**
```bash
sudo rmmod ftdi_sio
sudo modprobe -r ftdi_sio
# Controleer blacklist:
cat /etc/modprobe.d/radioberry-ftdi.conf
```

**Build mislukt (libftdi niet gevonden):**
```bash
sudo apt-get install -y libftdi1-dev libusb-1.0-0-dev pkg-config
```

**I2C preamp board niet zichtbaar (RPi):**
```bash
# Controleer of I2C aan staat:
sudo raspi-config → Interface Options → I2C
# Of:
i2cdetect -y 1
```

---

## Mappenstructuur na installatie

```
/usr/local/bin/radioberry-juice      ← firmware binary
/etc/radioberry/radioberry.rbf       ← FPGA gateware
/etc/modprobe.d/radioberry-ftdi.conf ← ftdi_sio blacklist
/etc/udev/rules.d/99-radioberry-ftdi.rules ← USB toegang
/etc/systemd/system/radioberry-juice.service ← autostart
~/radioberry[-juice]/Radioberry-2.x/ ← broncode
```

---

## Bijdragen

Zie [CONTRIBUTING.md](CONTRIBUTING.md) voor richtlijnen.
Bug melden? Gebruik de [issue tracker](.github/ISSUE_TEMPLATE/).

---

## Licentie

Scripts gepubliceerd onder de [MIT Licentie](LICENSE).
Radioberry hardware en firmware: zie de [originele repository van PA3GSB](https://github.com/pa3gsb/Radioberry-2.x).

---

*73 de PA3GSB — Scripts samengesteld met ondersteuning van Claude (Anthropic)*
