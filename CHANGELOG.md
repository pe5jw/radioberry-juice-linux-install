# Changelog

Alle noemenswaardige wijzigingen in dit project worden hier bijgehouden.
Formaat gebaseerd op [Keep a Changelog](https://keepachangelog.com/nl/1.1.0/).

---

## [1.1.0] — 2026-06-20

### Toegevoegd
- OS versiedetectie met duidelijke waarschuwingen bij verouderde versies
- Ondersteuning voor **Ubuntu 26.04 LTS** (Resolute Raccoon)
- Ondersteuning voor **Ubuntu 25.04** (Plucky Puffin)
- Ondersteuning voor **Debian 13 Trixie** (stabiel aug 2025)
- Ondersteuning voor **Raspberry Pi OS Trixie** (stabiel okt 2025)
- Pi 5 + Trixie: automatisch `i2c-dev` laden via `/etc/modules`
- Automatische detectie van boot config pad (`/boot/firmware/config.txt` vs `/boot/config.txt`)
- Uitgebreide README met badges, tabellen, probleemoplossing en mappenstructuur
- CONTRIBUTING.md met richtlijnen voor bijdragen
- GitHub issue templates (bug report, feature request)
- GitHub Actions workflow voor shell script linting (ShellCheck)
- `.gitignore` en `LICENSE` (MIT)

### Gewijzigd
- RPi script: pakketlijst gesplitst per OS versie (Trixie / Bookworm / Bullseye)
- Linux script: uitgebreide case-statement voor alle ondersteunde OS versies
- README volledig herschreven met actuele OS versietabellen

### Verouderd
- Ubuntu 20.04 (Focal) — EOL april 2025, waarschuwing toegevoegd
- Debian 11 (Bullseye) — bijna EOL, waarschuwing toegevoegd
- Raspberry Pi OS Bullseye — verouderd, waarschuwing toegevoegd

---

## [1.0.0] — 2026-06-19

### Toegevoegd
- Eerste release van `radioberry_juice_linux_install.sh`
  - Ondersteuning Ubuntu 22.04/24.04, Debian 11/12
  - ftdi_sio blacklist, udev regels, firmware build, systemd service
- Eerste release van `radioberry_juice_rpi_install.sh`
  - Ondersteuning Raspberry Pi 4 en Pi 5
  - Pi model auto-detectie
  - SPI/I2C activering via config.txt
  - Optionele installatie piHPSDR / Quisk
- `github_upload.ps1` — Windows PowerShell upload script voor GitHub

---

## Toekomstige plannen

- [ ] Ondersteuning Raspberry Pi OS Trixie 64-bit Lite
- [ ] Automatische gateware download van GitHub releases
- [ ] Fedora / openSUSE ondersteuning verbeteren
- [ ] Uninstall script toevoegen
- [ ] Testscript voor USB verbindingscontrole
