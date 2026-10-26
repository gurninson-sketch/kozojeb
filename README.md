# Chimera Kozojeb 2.8.3

[Pobierz najnowszą paczkę](https://github.com/gurninson-sketch/kozojeb/releases/latest/download/Chimera_Kozojeb.mpackage) · [Wydania](https://github.com/gurninson-sketch/kozojeb/releases)

**Kozojeb** jest rozwinięciem oryginalnego **KozoBota**, którego autorem jest **Pipek**. Zachowujemy autorstwo oryginału; nazwa Kozojeb oznacza rozwijaną tutaj wersję.

Bot do Mudleta: patrol, walka i role drużynowe w Chimerze. Prowadzącym może być dowolny profil. Pozostałe profile wspierają walkę zgodnie ze swoją rolą; decyzję o odwrocie podejmuje prowadzący, korzystając z danych drużyny w GMCP.

## Instalacja

1. Na każdym profilu zatrzymaj poprzedniego bota: `/kozo stop` w KozoBocie lub `/kozojeb stop` w Kozojebie. Poczekaj na zakończenie walki oraz ruchu.
2. W Menedżerze pakietów Mudleta usuń starszą paczkę **Chimera_Kozojeb** lub poprzedniego **Chimera_Kozobot**. Zachowaj główne skrypty Chimery.
3. Zainstaluj `Chimera_Kozojeb.mpackage` pobrany z **Releases** tego repozytorium. Pozostaw jedną wersję Kozojeba na profilu.
4. Wpisz `/kozojeb status` i sprawdź numer wersji.
5. Pozostaw wyłączone dodatkowe automatyczne wsparcie w głównych skryptach Chimery.

Do automatycznych aktualizacji wymagany jest Mudlet **4.20.0 lub nowszy**. Kod głównego bota jest zgodny z Lua 5.1 i 5.4; testy nie zastępują sprawdzenia w grze.

## Drużyna i role

Najpierw utwórz drużynę w grze. Rola bota nie przekazuje faktycznego prowadzenia drużyny.

| Profil — przykład | Komendy konfiguracji | Zachowanie |
| --- | --- | --- |
| Yarrim | `/kozojeb rola prowadzacy` | Patrol, wybór celów, pościg, zasłony drużyny i wspólny odwrót |
| Morrid | `/kozojeb rola zaslony` oraz `/kozojeb lider auto` | Wsparcie i osłanianie prowadzącego |
| Yergo i Gror | `/kozojeb rola wsparcie` oraz `/kozojeb lider auto` | Druga linia: wsparcie i DPS, bez automatycznych zasłon |

Wspierający dołączają do walki przez `wesprzyj`; dalsze ataki wykonuje gra. Nie patrolują, nie ścigają przeciwników i nie wykonują własnego odwrotu, leczenia, `/idz` ani opuszczania drużyny. Nie przesyłają raportów między profilami. Ruch za prowadzącym zapewnia drużyna w grze.

Zmiana roli zatrzymuje bota. Po skonfigurowaniu uruchom go przez `/kozojeb start` na każdym profilu. Wspierających można uruchomić przed prowadzącym. Bez widocznego, faktycznego prowadzącego czekają.

Możesz wskazać konkretnego prowadzącego zamiast automatycznego wykrywania:

```text
/kozojeb lider Yarrim yarrima
```

## Obszar i cele prowadzącego

1. Zaznacz pokoje na mapie i wpisz `/kozojeb obszar`.
2. Wybierz cele, np. `/kozojeb cele snotling`. Komenda zastępuje całą listę celów.
3. Zbierz drużynę w bezpiecznym pokoju znajdującym się w obszarze.
4. Wpisz `/kozojeb start`. Bieżący pokój prowadzącego staje się bazą i początkiem patrolu.

Przykładowe ustawienia:

```text
/kozojeb maxstworow 3
/kozojeb predkosc 0.7
/kozojeb pauza 5
/kozojeb prog 50
/kozojeb progdruzyny 50
/kozojeb progzaslony 70
/kozojeb odpoczynek 25 55
```

Limit stworów dotyczy rozpoczynania nowego ataku. Agresywny NPC może rozpocząć walkę niezależnie od tego limitu. `/kozojeb baza` zmienia bazę na bieżący pokój, ale kolejne `/kozojeb start` ponownie ustawia ją w miejscu uruchomienia.

## Zasłony i HP

Własne HP jest liczone z kompletnej pary `hp/maxhp` z jednego źródła GMCP. Niepełny odczyt nie łączy wartości z `Char.Vitals` i `Room.Entities`; jeśli oba źródła są niepełne, bot zachowuje ostatni poprawny wynik. Pełne, nowsze `Char.Vitals` nadal ma pierwszeństwo przed starszym odczytem encji.

Na profilu osłaniającym prowadzącego:

```text
/kozojeb proglidera 85
/kozojeb minhpzaslony 50
```

Zasłona następuje, gdy HP prowadzącego jest **poniżej 85%**, własne HP wynosi **co najmniej 50%**, a żywy NPC faktycznie atakuje prowadzącego i szyk jest gotowy. Przy równych 85% zasłona nie następuje. `/kozojeb proglidera 0` wyłącza tę zasłonę.

`/kozojeb progzaslony 70` ustawia zasłony wykonywane przez prowadzącego na rannych członkach drużyny. Ten próg musi być wyższy od progów odwrotu. Własne minimum `/kozojeb minhpzaslony` działa niezależnie w obu rolach wykonujących zasłony. Na wspierającym `/kozojeb prog 50` jest skrótem ustawienia własnego minimum zasłon; na prowadzącym pozostaje progiem odwrotu.

Po otrzymaniu osłony od prowadzącego ranny wspierający wstrzymuje własne zasłony. Wraca do nich po zakończeniu walki albo gdy ma co najmniej **5 punktów procentowych HP więcej od prowadzącego**. Zapobiega to natychmiastowemu odwracaniu osłony. Pozostałe warunki zasłon nadal obowiązują.

Każda próba rezerwuje zmianę szyku od razu. Bot czeka na `Jestes gotowy do zmiany w szyku.`; limit awaryjny przy braku komunikatu wynosi 10 sekund. Nieudana próba umiejętności również zużywa gotowość szyku.

Odmiany imion są zapisane dla Yarrima, Morrida, Yerga i Grora. Dla kolejnej postaci ustaw biernik, np.:

```text
/kozojeb imie Pandjed pandjeda
/kozojeb imie lista
```

Niepoprawna forma odrzucona przez grę jest blokowana do poprawienia.

## Odwrót, sprzęt i ponowne logowanie

- Prowadzący decyduje o odwrocie według własnego HP, HP drużyny i własnego zmęczenia.
- Po odwrocie czeka na swoje pełne HP, wymagany poziom ruchu oraz obecność i znane HP wcześniej widocznych członków drużyny. Osoba, której rany wywołały odwrót, musi odzyskać 100% HP.
- Pęknięcie własnego lub widocznego drużynowego ekwipunku uruchamia wspólny odwrót i blokuje automatyczne wznowienie. Uzupełnij sprzęt i wpisz na prowadzącym `/kozojeb ekwipunek gotowy`.
- Rozłączenie wstrzymuje komendy i zapamiętuje aktywne zadanie. Po ponownym zalogowaniu Kozojeb **automatycznie je wznawia, bez `/kozojeb start`**. Czeka na świeże dane pokoju, postaci, HP/ruchu, walki i drużyny. Przed wznowieniem patrolu prowadzący czeka też na wcześniej widocznych członków drużyny. Ich nieobecność nie blokuje pilnego odwrotu ani kontynuacji leczenia; zebranie drużyny jest wtedy sprawdzane w bazie. Wspierający wracają do swoich ról bez własnego ruchu.
- Automatyczne wznowienie zachowuje bazę, obszar i postęp patrolu. Trwający odwrót, leczenie lub powrót jest kontynuowany. Cel walki i kolejny krok są wybierane ponownie z aktualnych danych. Logowanie i ponowne połączenie obsługuje Mudlet oraz dotychczasowa konfiguracja profilu.
- `/kozojeb stop` anuluje również oczekujące wznowienie. Bot zatrzymany przed rozłączeniem pozostaje zatrzymany. Zmiana roli anuluje poprzednie zadanie; logowanie inną postacią również go nie wznawia. Po aktualizacji paczki bot pozostaje zatrzymany.
- Po wysłaniu ruchu bot czeka na potwierdzenie pokoju i nową listę encji, zanim wybierze cel do ataku.

`/kozojeb stop` zatrzymuje Kozojeba na danym profilu. Zatrzymanie wszystkich profili wymaga tej komendy na każdym z nich. Trwającą walkę i zewnętrzny chodzik obsługuje gra oraz główne skrypty Chimery.

## Aktualizacje z GitHuba

Jeśli masz już Kozojeba 2.8.1 lub 2.8.2, wykonaj na **każdym profilu**:

```text
/kozojeb stop
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Poczekaj na zakończenie walki i ruchu oraz komunikat `Zainstalowano 2.8.3`. Sprawdź `/kozojeb status`; powinien pokazać wersję **2.8.3**. Następnie uruchom `/kozojeb start` — najpierw na wspierających, potem na prowadzącym. To jednorazowy start po aktualizacji; późniejsze rozłączenia nie wymagają ręcznego wznowienia. Nie trzeba usuwać ani ręcznie instalować paczki; ustawienia profili pozostają zachowane.

Przy paczce zbudowanej w tym repozytorium adres wydań jest wbudowany. W paczce przygotowanej bez adresu skonfiguruj na każdym profilu:

```text
/kozojeb repo gurninson-sketch/kozojeb
/kozojeb autoaktualizacja on
/kozojeb aktualizuj
```

Adres repozytorium ma postać `OWNER/REPO`, bez `https://`. Repozytorium z wydaniami musi być publicznie dostępne. Ta wersja aktualizatora nie przechowuje tokenów GitHuba i nie pobiera prywatnych wydań.

Aktualizator sprawdza wydanie 30 sekund po załadowaniu profilu, a następnie co 6 godzin. Ręczne `/kozojeb aktualizuj` działa również przy wyłączonym sprawdzaniu automatycznym. Pobiera tylko opublikowane stabilne wydania z **Releases**. Zmiany na `main` i wydania robocze nie aktualizują profili.

Instalacja czeka na zatrzymanie bota, zakończenie własnej walki i aktualne dane pokoju. Nie zatrzymuje samodzielnie prowadzącego ani wspierających. Bot po aktualizacji pozostaje zatrzymany; uruchom go przez `/kozojeb start`.

Przed podmianą sprawdzane są rozmiar, format i SHA-256 paczki. Bieżące skrypty są zachowywane w kopii `kozojeb_rollback/Chimera_Kozojeb.xml` w katalogu profilu. Gdy nowa wersja nie zainstaluje się poprawnie, aktualizator próbuje przywrócić tę kopię. Można ją też zainstalować ręcznie przez Menedżer pakietów.

Konfiguracja — w tym obszar, cele, prędkości, progi, role i odmiany — pozostaje w katalogu danego profilu, poza katalogiem paczki. Aktualizacja nie przenosi ustawień pomiędzy postaciami. Pierwsze przejście z KozoBota importuje dostępne wcześniejsze ustawienia profilu i obszar; po zmianach zapisz profil Mudleta.

## Dla autora zmian

Wymagane: Python 3.10+ oraz biblioteka Lua 5.4 albo Lua 5.1. Na Ubuntu: `sudo apt-get install liblua5.4-0`.

```sh
python3 tools/test.py
python3 tools/build.py --repository gurninson-sketch/kozojeb
```

Paczka i `update.json` powstaną w `dist/`. Budowanie jest powtarzalne dla tego samego kodu i adresu repozytorium. Testy używają atrap API Mudleta, timerów, GMCP i pobierania plików.

Wydanie:

1. Zmień `VERSION`, `K.version`, nagłówek pomocy i opis zmian.
2. Uruchom testy i zatwierdź kod.
3. Utwórz tag, np. `git tag v2.8.0`, i wypchnij go do GitHuba.
4. Workflow **Release** uruchomi testy, zbuduje paczkę i utworzy wydanie robocze.
5. Sprawdź wydanie robocze i opublikuj je. Od tej chwili profile wykryją nową wersję.

Przy wypchnięciu pierwszego tagu razem z nowymi workflowami można też uruchomić **Release → Run workflow** z istniejącym tagiem. GitHub wymaga włączonych Actions w repozytorium.

Do repozytorium trafiają wyłącznie źródła, testy i dokumentacja. Logi postaci, mapy i ustawienia profili nie są częścią projektu.
