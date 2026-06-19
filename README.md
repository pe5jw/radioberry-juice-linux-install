# Radioberry 2.x - Linux USB Install Scripts

Install scripts voor de **Radioberry 2.x** SDR transceiver met het **Juice Board (FT2232H)** via USB.

Gebaseerd op het open source project van Johan PA3GSB:
- Website: [https://www.pa3gsb.nl](https://www.pa3gsb.nl)
- Radioberry GitHub: [https://github.com/pa3gsb/Radioberry-2.x](https://github.com/pa3gsb/Radioberry-2.x)

---

## Wat is de Radioberry?

De Radioberry is een SDR transceiver als Raspberry Pi hat, gebaseerd op de **Analog Devices AD9866** (0–30 MHz, 12-bit DDC/DUC) en een **Intel Cyclone 10LP FPGA**.

Het **Juice Board** voegt een **FTDI FT2232H** USB interface toe, waardoor de Radioberry via USB aangesloten kan worden op een gewone Linux PC of Raspberry Pi — zonder dat een RPi als host vereist is.

```
[ Radioberry 2.x kaart ]
         |
[ Juice Board (FT2232H) ]
         |
    [ USB kabel ]
         |
  [ Linux PC / RPi 4 / RPi 5 ]
         |
  [ SDR software: piHPSDR / Quisk / SparkSDR ]
```

---

## Scripts

### 1. `radioberry_juice_linux_install.sh`
Voor **Ubuntu / Debian** Linux op een gewone x86_64 PC.

**Wat het doet:**
- Installeert libftdi1, build-essential, git, cmake
- Blokkeert de `ftdi_sio` kernelmodule (zodat libftdi directe USB-toegang heeft)
- Maakt udev regels aan voor niet-root toegang tot FT2232H (FTDI 0403:6010)
- Kloont de Radioberry repo en bouwt de Juice firmware
- Installeert firmware naar `/usr/local/bin/radioberry-juice`
- Installeert gateware naar `/etc/radioberry/radioberry.rbf`
- Maakt een systemd service aan voor autostart
- Ondersteunt: Ubuntu 20.04 / 22.04 / 24.04, Debian 11 / 12

**Gebruik:**
```bash
chmod +x radioberry_juice_linux_install.sh
./radioberry_juice_linux_install.sh
```

---

### 2. `radioberry_juice_rpi_install.sh`
Voor **Raspberry Pi 4** en **Raspberry Pi 5** (Raspberry Pi OS Bullseye / Bookworm).

**Wat het doet:**
- Detecteert automatisch Pi 4 of Pi 5 en past zich aan
- Installeert alle vereiste pakketten inclusief GPIO/I2C libraries
- Blokkeert `ftdi_sio`, maakt udev regels aan
- Schakelt SPI en I2C in via `config.txt` (voor preamp board)
- Bouwt en installeert de Juice firmware
- Maakt systemd service aan
- Optioneel: installeert **piHPSDR** en/of **Quisk** via keuzemenu
- Vraagt aan het einde om te herstarten

**Gebruik:**
```bash
chmod +x radioberry_juice_rpi_install.sh
./radioberry_juice_rpi_install.sh
```

---

## Hardware benodigdheden

| Onderdeel | Omschrijving |
|---|---|
| Radioberry 2.x | SDR kaart (AD9866 + Cyclone 10LP FPGA) |
| Juice Board | FT2232H USB interface board (vervangt de RPi als host) |
| USB-A kabel | Juice Board → PC of RPi |
| 12V DC voeding | Voor het Juice Board (eigen voeding, niet via Pi GPIO) |
| Antenne | 50 ohm HF antenne, 0–30 MHz |
| (optioneel) Preamp board | 5W versterker, klikt op Radioberry (I2C sturing) |

---

## Aansluitvolgorde

1. Steek de Radioberry 2.x kaart op het Juice Board
2. Verbind de 12V voeding met het Juice Board
3. Verbind de USB kabel: Juice Board → PC / RPi
4. Start de firmware: `radioberry-juice`
5. Start SDR software en gebruik OpenHPSDR Protocol-1 discovery (UDP)

---

## SDR Software

| Software | Platform | Protocol |
|---|---|---|
| [piHPSDR](https://github.com/dl1ycf/pihpsdr) | Linux / RPi | OpenHPSDR P1 |
| [Quisk](https://james.ahlstrom.name/quisk/) | Linux / Windows / Mac | OpenHPSDR P1 |
| [SparkSDR](https://www.sparksdr.com/) | Windows / Linux | OpenHPSDR P1 |
| [Thetis](https://github.com/TAPR/OpenHPSDR-Thetis) | Windows | OpenHPSDR P1 |
| [linHPSDR](https://github.com/LightHFRadio/linHPSDR) | Linux | OpenHPSDR P1 |

---

## Prestaties (Juice Board / FT2232H)

- FT2232H FT245 protocol, klok: 60 MHz → max 480 Mbps
- Gemeten doorvoer op Linux RPi4: ~320 Mbps
- Gemeten doorvoer op Windows laptop: ~386 Mbps
- Bandbreedte per ontvanger bij 384 kHz: ~6 gelijktijdige ontvangers mogelijk

---

## Verwijzingen

- [pa3gsb.nl](https://www.pa3gsb.nl) — Project website Johan PA3GSB
- [Radioberry 2.x GitHub](https://github.com/pa3gsb/Radioberry-2.x) — Broncode, hardware, firmware
- [Radioberry Wiki](https://github.com/pa3gsb/Radioberry-2.x/wiki) — Documentatie
- [Google Groups Forum](https://groups.google.com/g/radioberry) — Community
- [Hermes-Lite 2](https://github.com/softerhardware/Hermes-Lite2) — Inspiratiebron

---

## Licentie

Scripts gepubliceerd onder MIT licentie. Radioberry hardware en firmware zijn open source (zie de originele repository van PA3GSB voor licentiedetails).

---

*73 de PA3GSB / Scripts samengesteld met Claude (Anthropic)*
