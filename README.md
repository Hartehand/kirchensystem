# Kirchensteuer-System (DarkRP)

Produktionsreifes Kirchensteuer-Addon für Garry’s Mod DarkRP mit Bischof-SWEP, Verwaltungsmenü, automatischem Beitragseinzug, zentralem Kirchenkonto für Einnahmen und MySQL-Persistenz (mysqloo oder tmysql4).

## Ordnerstruktur

```
lua/
  autorun/kirche_init.lua
  kirche/
    sh_config.lua
    sh_net.lua
    server/
      sv_mysql.lua
      sv_core.lua
      sv_charges.lua
    client/
      cl_request.lua
      cl_bishop_menu.lua
  weapons/weapon_kirche/
    shared.lua
    init.lua
    cl_init.lua
```

## Installation

1. **Dependencies**
   - `mysqloo` (empfohlen) oder `tmysql4` auf dem Server installieren.
   - DarkRP muss geladen sein (nutzt `DarkRP.notify`, `addMoney`, `getDarkRPVar`).

2. **Addon kopieren**
   - Repo-Inhalt in deinen `garrysmod/addons/kirchensystem`-Ordner legen.

3. **Konfiguration** (`lua/kirche/sh_config.lua`)
   - `BishopTeam` auf das Landesbischof-Team setzen (z. B. `TEAM_LANDESBISCHOF`).
   - Datenbankzugang (`Database`) und Adapter (`Adapter = "mysqloo"` oder `"tmysql4"`) setzen. **Wichtig:** `database` muss exakt der bestehenden Datenbank (z. B. `db_422750_80`) entsprechen; Tabellen `kirche_members`/`kirche_logs` werden beim Start automatisch erzeugt.
   - Beitragsspannen, Intervalle, Benachrichtigungen, Schulden-Limits anpassen.
   - Optional kann `BishopTeam` ein einzelner Team-Index oder eine Tabelle aus mehreren Team-Indizes sein, falls mehrere Bischof-Ränge erlaubt werden sollen.
   - Kirchenkonto: Alle eingezogenen Beiträge landen automatisch auf dem Konto; der Bischof kann über das Menü beliebig einzahlen oder auszahlen.

4. **SWEP vergeben**
   - SWEP-Klassenname: `weapon_kirche` (configurierbar).
   - Nur das Bischof-Team kann es nutzen; falsche Teams werden beim Equip entwaffnet.

5. **Chat-Command**
   - Bischof-Menü per `/kirche` oder Rechtsklick mit dem SWEP öffnen.

## SQL-Schema

```sql
CREATE TABLE IF NOT EXISTS kirche_members (
  steamid64 VARCHAR(32) NOT NULL PRIMARY KEY,
  rpname VARCHAR(255) NOT NULL,
  joined_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  contribution INT NOT NULL DEFAULT 50,
  debt INT NOT NULL DEFAULT 0,
  last_charge_at DATETIME NULL
);

CREATE TABLE IF NOT EXISTS kirche_logs (
  id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  steamid64 VARCHAR(32) NOT NULL,
  action VARCHAR(64) NOT NULL,
  amount INT NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS kirche_account (
  id TINYINT NOT NULL PRIMARY KEY,
  balance BIGINT NOT NULL DEFAULT 0
);

INSERT INTO kirche_account (id, balance) VALUES (1, 0)
  ON DUPLICATE KEY UPDATE balance = balance;
```

## Testplan (manuell)

1. **Beitrittsanfrage**
   - Als Bischof SWEP ziehen, auf Spieler linken Klick → Spieler sieht Dialog, akzeptiert → Mitglied in DB.
2. **„Bereits Mitglied“**
   - Erneut denselben Spieler anvisieren → Bischof erhält Hinweis mit Beitrag/Schulden.
3. **Beitrag ändern**
   - Menü `/kirche` öffnen, Mitglied wählen, Slider anpassen → speichern → DB-Update prüfen.
4. **Automatischer Einzug**
   - Charge-Intervall abwarten; mit genug Geld wird Beitrag abgezogen, sonst Schulden angelegt.
5. **Schuldenabbau**
   - Spieler mit Schulden erneut einziehen lassen, nachdem er Geld hat → Schulden reduzieren/tilgen.
6. **Mitglied entfernen**
   - Menü: Mitglied entfernen → Datensatz aus DB gelöscht, Cache aktualisiert.
7. **Schulden-Reset (optional)**
   - `AllowDebtReset = true`, Button testen.
8. **Kirchenkonto**
   - Nach Einzügen Kontostand prüfen, Einzahlen- und Abheben-Buttons testen (Betrag wird vom Bischofskonto abgezogen bzw. gutgeschrieben).
