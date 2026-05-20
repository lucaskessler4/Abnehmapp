# Kalorien Kompass

Eine erste native iOS-App zum Abnehmen: Tagesziel berechnen, Mahlzeiten eintragen und später per Foto-Scan erweitern.

## Was schon funktioniert

- Tagesübersicht mit Ziel, gegessenen Kalorien, Restkalorien und Protein.
- Schnelles Hinzufügen von Mahlzeiten mit Name, kcal und Protein.
- Lokale Speicherung auf dem iPhone per `UserDefaults`.
- Bedarf-Rechner mit Geschlecht, Alter, Größe, Gewicht, Aktivität und Zieltempo.
- Platzhalter-Tab für den späteren KI-Foto-Scan.

## Auf dem iPhone öffnen

1. Installiere Xcode aus dem Mac App Store.
2. Öffne `KalorienKompass.xcodeproj` mit Xcode.
3. Verbinde dein iPhone per Kabel oder aktiviere es in Xcode als drahtloses Gerät.
4. Wähle oben in Xcode neben dem Play-Button dein iPhone als Zielgerät aus.
5. Öffne in Xcode `Signing & Capabilities` und wähle bei `Team` deine Apple-ID aus.
6. Klicke auf den Play-Button. Xcode baut die App und installiert sie auf deinem iPhone.

Beim ersten Mal kann dein iPhone unter `Einstellungen > Allgemein > VPN & Geräteverwaltung` fragen, ob du deiner Entwickler-App vertraust.

## Nächster sinnvoller Schritt

Der Foto-Scan bekommt später Kamera-Zugriff, nimmt ein Essensfoto auf, sendet es an ein KI-Modell und legt das Ergebnis erst als Vorschlag an. So kannst du kontrollieren, bevor Kalorien in den Tag übernommen werden.
