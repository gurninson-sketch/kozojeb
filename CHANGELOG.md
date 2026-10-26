# Zmiany

## 2.8.0

- Projekt rozwijany pod nazwą Kozojeb, z zachowaniem informacji o oryginalnym KozoBocie i jego autorze. Nowa komenda główna: `/kozojeb`.

- Zatrzymanie po rozłączeniu; blokada komend podczas logowania i oczekiwanie na świeże dane przed ręcznym wznowieniem.
- Wstrzymanie zasłon wspierającego po otrzymaniu osłony od prowadzącego, z marginesem 5 punktów procentowych HP przed ponownym przejęciem zagrożenia.
- Wspólny odwrót po pęknięciu własnego lub drużynowego ekwipunku. Wznowienie wymaga `/kozojeb ekwipunek gotowy`.
- Sprawdzanie wcześniej obecnych członków drużyny przed wznowieniem po leczeniu.
- Blokada ataku na dane poprzedniego pokoju po wysłaniu ruchu oraz pomijanie odrzuconego wyjścia.
- Relacje walki obcych NPC nie są uznawane za własną walkę prowadzącego.
- Świeży pakiet `Char.Vitals` ma pierwszeństwo przed starszym HP własnej postaci w encjach pokoju.
- Pełny zapis ustawień profilu i obszaru; migracja starszego pliku ustawień ról.
- Ograniczenie tekstowych zapytań o kondycję podczas leczenia i usunięcie nieobsługiwanego wywołania `/mm follow`.
- Aktualizator publicznych wydań GitHub: kontrola SHA-256, oczekiwanie na stop i koniec walki, kopia oraz próba przywrócenia poprzedniej wersji.
- Automatyczne testy i budowanie paczek przez GitHub Actions.

## 2.7.2

- Rezerwowanie szyku przy wysłaniu próby zasłony.
- Wybór chronionej osoby według kierunku relacji NPC → gracz.
- Niezależne minimum HP zasłaniającego.

## 2.7.1

- Usunięcie wszystkich dróg samodzielnego odwrotu wspierających.

## 2.7.0

- Role prowadzącego, drugiej linii oraz wsparcia z zasłonami.
- Automatyczne wykrywanie faktycznego prowadzącego przez GMCP.
- Odmiany imion i ustawienia ról osobno na każdym profilu.
