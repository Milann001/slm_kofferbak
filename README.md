🚗 Advanced Trunk System (FiveM)
Een geavanceerde en realistische resource voor FiveM waarmee spelers in de kofferbak van voertuigen kunnen liggen. Volledig gebouwd op het OX-systeem (ox_lib & ox_target) voor optimale prestaties en veiligheid.

✨ Kenmerken
Ox_target Integratie: Geen commando's nodig, richt simpelweg op de kofferbak van een voertuig.

Anti-Glitch Systeem: Gebruikt Server-side callbacks om te voorkomen dat meerdere spelers tegelijk in dezelfde kofferbak klimmen.

Realistische Checks:

De actie wordt direct afgebroken als iemand in het voertuig stapt tijdens het proces.

Spelers kunnen alleen uitstappen als het voertuig volledig stilstaat.

Automatische detectie of een voertuig een kofferbak heeft en groot genoeg is.

Inventory Block: Maakt gebruik van state bags (invBusy) om de ox_inventory volledig te blokkeren terwijl je in de kofferbak ligt.

Slimme Positionering: Berekent dynamisch de grootte van het voertuig voor een perfecte spawn-positie bij het uitstappen (geen collision bugs).

Onzichtbaarheid: Verbergt het speler-model in de kofferbak om clipping door voertuigonderdelen te voorkomen.

📦 Afhankelijkheden
ox_lib

ox_target

ox_inventory (Optioneel, voor de inventory block)

🛠️ Installatie
Download de repository.

Plaats de map in je resources directory.

Zorg dat de afhankelijkheden (ox_lib en ox_target) gestart worden voor deze resource.

Voeg ensure [resourcenaam] toe aan je server.cfg.

⚙️ Configuratie
In de config.lua kun je de volgende zaken aanpassen:

ActionDuration: Hoe lang het duurt om in/uit te stappen.

AllowedClasses: Welke voertuigtypes (sedans, SUV's, etc.) toegestaan zijn.

CustomOffsets: Specifieke coördinaten voor voertuigen die een unieke kofferbakvorm hebben.

📜 Gebruik
Loop naar de achterkant van een voertuig.

Gebruik je target-key (standaard ALT) en klik op de kofferbak.

Selecteer "In kofferbak liggen".

Om uit te stappen: Wacht tot de auto stilstaat en druk op [E].

Zoals je misschien ook al aan het stukje tekst hierboven kan zien is deze resource volledig met AI gemaakt. Alles is getest en werkt ook zoals het hoort!
