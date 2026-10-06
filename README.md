# AutoAudioSwitch

Bascule automatique des périphériques audio / micro sous Windows 11.

## Règles

- **Pixel Buds connectés** → sortie + micro Pixel (pas Hands-Free)
- **Razer BlackShark V3 Pro allumé** (lien 2.4 GHz réel via HID dongle) → sortie Game + micro Chat
- **Sinon** → Philips Evnia (écran)

Si les deux casques sont actifs : **le dernier connecté gagne**.
Au démarrage : `Pixel > Razer (HID) > écran`.

## Comment ça marche

- `AutoAudioSwitch.ps1` : watcher en boucle (toutes les 2 s).
  - Pixel détecté via `Get-PnpDevice -Class Bluetooth` (`*Pixel Buds*` + Status `OK`).
  - Razer détecté via `RazerDongle.cs` : requête HID propriétaire sur le dongle
    `VID 1532 / PID 0577` (même query que Synapse `getWirelessConnectionStatus`).
    Ça évite le faux positif « dongle toujours visible même casque éteint ».
  - Bascule via `Set-AudioDevice` (défaut + communication).
- `RazerDongle.cs` : helper C# compilé à la volée (`Add-Type`), énumère les HID et interroge le `col04` du dongle.
- `Modules/AudioDeviceCmdlets/3.1.0.2/` : module tiers embarqué (voir crédits).

## Contenu

| Fichier | Rôle |
|---|---|
| `AutoAudioSwitch.ps1` | Watcher principal |
| `RazerDongle.cs` | Détection lien 2.4 GHz Razer via HID |
| `Start-AutoAudioSwitch.vbs` | Lancement caché (sans console) |
| `Stop-AutoAudioSwitch.ps1` / `.vbs` / `.cmd` | Arrêt du watcher |
| `Modules/AudioDeviceCmdlets/` | Dépendance audio embarquée |

## Installation

1. Télécharger la release et extraire où tu veux (ex. `C:\Tools\AutoAudioSwitch\`).
2. Double-cliquer `Start-AutoAudioSwitch.vbs` pour démarrer.
3. Pour démarrage auto avec Windows :
   - `Win + R` → `shell:startup`
   - Créer un raccourci vers `Start-AutoAudioSwitch.vbs`.

## Arrêt

Double-cliquer `Stop-AutoAudioSwitch.vbs` (ou `.cmd` pour voir la sortie console).

## Logs / état

- Logs : `%LOCALAPPDATA%\AutoAudioSwitch\log.txt`
- Dernier profil appliqué : `%LOCALAPPDATA%\AutoAudioSwitch\state.txt` (`Pixel`, `Razer` ou `Screen`)

## Prérequis

- Windows 11
- Windows PowerShell 5.1 (`powershell.exe`)
- Casque(s) concernés : Pixel Buds, Razer BlackShark V3 Pro (dongle `1532:0577`), écran Philips Evnia

> Les noms de périphériques sont en dur dans `AutoAudioSwitch.ps1` (`Find-Device`).
> Adapte les motifs `*Pixel Buds*`, `*BlackShark*Game*`, `*BlackShark*Chat*`, `*Philips Evnia*` si besoin.

## Crédits

- [AudioDeviceCmdlets](https://github.com/frgnca/AudioDeviceCmdlets) par François Gendron — MIT License (embarqué dans `Modules/`).

## Licence

MIT — voir [LICENSE](LICENSE).
