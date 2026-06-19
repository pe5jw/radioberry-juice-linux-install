# Bijdragen aan Radioberry Juice Linux Install Scripts

Bedankt voor je interesse in bijdragen! Dit project is bedoeld voor de amateur radio community rondom de Radioberry van PA3GSB.

---

## Hoe bijdragen?

### 🐛 Bug melden

Gebruik de [issue tracker](../../issues) en kies **Bug Report**.
Geef altijd mee:
- OS versie (`cat /etc/os-release`)
- Pi model (indien van toepassing): `cat /proc/device-tree/model`
- Volledige foutmelding (kopieer de terminal output)
- Stappen om de fout te reproduceren

### 💡 Feature verzoek

Gebruik de [issue tracker](../../issues) en kies **Feature Request**.

### 🔧 Code bijdragen

1. Fork de repository
2. Maak een branch aan: `git checkout -b feature/mijn-verbetering`
3. Maak je wijzigingen
4. Test op het betreffende platform
5. Controleer met ShellCheck: `shellcheck jouw_script.sh`
6. Commit: `git commit -m "Beschrijving van wijziging"`
7. Push: `git push origin feature/mijn-verbetering`
8. Open een Pull Request

---

## Codestijl

- Gebruik `#!/bin/bash` als shebang (niet `sh`)
- Variabelen in HOOFDLETTERS voor globale variabelen
- Gebruik de bestaande `log()`, `warn()`, `error()`, `info()` functies voor output
- Elke stap heeft een duidelijke `STAP N:` header
- Voeg commentaar toe bij niet-triviale commando's
- Test altijd met `shellcheck` voor je een PR opent:
  ```bash
  sudo apt install shellcheck
  shellcheck radioberry_juice_linux_install.sh
  shellcheck radioberry_juice_rpi_install.sh
  ```

---

## Platforms om te testen

Scripts moeten werken op:

**Linux PC:**
- Ubuntu 24.04 LTS of 26.04 LTS (aanbevolen voor testen)
- Debian 13 Trixie

**Raspberry Pi:**
- RPi 4 of RPi 5 met Raspberry Pi OS Trixie (Debian 13) — aanbevolen
- RPi 4 of RPi 5 met Raspberry Pi OS Bookworm (Debian 12)

---

## Vragen?

Stel je vraag in het [Radioberry Google Groups forum](https://groups.google.com/g/radioberry) of open een [issue](../../issues).

73 de PA3GSB
