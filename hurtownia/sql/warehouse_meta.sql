----------------------------------------------------------------------
-- 1. PODŁĄCZENIE BAZ ŹRÓDŁOWYCH
----------------------------------------------------------------------

ATTACH DATABASE 'hotel.db'     AS hotel;
ATTACH DATABASE 'platnosci.db' AS platnosci;

----------------------------------------------------------------------
-- 2. USUNIĘCIE STARYCH TABEL
----------------------------------------------------------------------

DROP TABLE IF EXISTS FAKT_REZERWACJA;
DROP TABLE IF EXISTS FAKT_TRANSAKCJA;

DROP TABLE IF EXISTS DIM_HOTEL;
DROP TABLE IF EXISTS DIM_KLIENT;
DROP TABLE IF EXISTS DIM_POKOJ;
DROP TABLE IF EXISTS DIM_USLUGA_DODATKOWA;
DROP TABLE IF EXISTS DIM_CZAS;

----------------------------------------------------------------------
-- 3. TWORZENIE TABEL WYMIARÓW
----------------------------------------------------------------------

CREATE TABLE DIM_HOTEL (
    HotelID         INTEGER PRIMARY KEY,
    Miasto          TEXT,
    Kraj            TEXT,
    StandardGwiazd  INTEGER
);

CREATE TABLE DIM_KLIENT (
    KlientID        INTEGER PRIMARY KEY,
    Segment         TEXT,
    KrajPochodzenia TEXT
);

CREATE TABLE DIM_POKOJ (
    PokojID      INTEGER PRIMARY KEY,
    TypPokoju    TEXT,
    CenaZaNoc    REAL,
    LiczbaMiejsc INTEGER
);

CREATE TABLE DIM_USLUGA_DODATKOWA (
    UslugaID       INTEGER PRIMARY KEY,
    TypUslugi      TEXT,
    CenaZaUsluge   REAL
);

CREATE TABLE DIM_CZAS (
    CzasID        INTEGER PRIMARY KEY AUTOINCREMENT,
    Dzien         INTEGER,
    Miesiac       INTEGER,
    Kwartal       INTEGER,
    Rok           INTEGER,
    DzienTygodnia INTEGER,
    CzyWeekend    INTEGER,
    LiczbaNocy    INTEGER
);

----------------------------------------------------------------------
-- 4. TWORZENIE TABEL FAKTÓW
----------------------------------------------------------------------

CREATE TABLE FAKT_REZERWACJA (
    FaktRezerwacjaID INTEGER PRIMARY KEY AUTOINCREMENT,
    KlientID         INTEGER,
    HotelID          INTEGER,
    PokojID          INTEGER,
    CzasID           INTEGER,
    LiczbaRezerwacji INTEGER,
    FOREIGN KEY (KlientID) REFERENCES DIM_KLIENT(KlientID),
    FOREIGN KEY (HotelID) REFERENCES DIM_HOTEL(HotelID),
    FOREIGN KEY (PokojID) REFERENCES DIM_POKOJ(PokojID),
    FOREIGN KEY (CzasID) REFERENCES DIM_CZAS(CzasID)
);

CREATE TABLE FAKT_TRANSAKCJA (
    FaktTransakcjaID INTEGER PRIMARY KEY AUTOINCREMENT,
    KlientID         INTEGER,
    HotelID          INTEGER,
    CzasID           INTEGER,
    UslugaID         INTEGER,
    LiczbaTransakcji INTEGER,
    FOREIGN KEY (KlientID) REFERENCES DIM_KLIENT(KlientID),
    FOREIGN KEY (HotelID) REFERENCES DIM_HOTEL(HotelID),
    FOREIGN KEY (CzasID) REFERENCES DIM_CZAS(CzasID),
    FOREIGN KEY (UslugaID) REFERENCES DIM_USLUGA_DODATKOWA(UslugaID)
);

----------------------------------------------------------------------
-- 5. ŁADOWANIE DANYCH DO WYMIARÓW
----------------------------------------------------------------------

-- HOTEL
INSERT INTO DIM_HOTEL (HotelID, Miasto, Kraj, StandardGwiazd)
SELECT HotelID, Miasto, Kraj, Standard
FROM hotel.Hotel;

-- KLIENT
INSERT INTO DIM_KLIENT (KlientID, Segment, KrajPochodzenia)
SELECT KlientID, Segment, KrajPochodzenia
FROM hotel.Klient;

-- POKÓJ
INSERT INTO DIM_POKOJ (PokojID, TypPokoju, CenaZaNoc, LiczbaMiejsc)
SELECT PokojID, Typ, CenaZaNoc, LiczbaMiejsc
FROM hotel.Pokoj;

-- USŁUGI DODATKOWE
INSERT INTO DIM_USLUGA_DODATKOWA (UslugaID, TypUslugi, CenaZaUsluge)
SELECT UslugaID, Rodzaj, Kwota
FROM platnosci.UslugaDodatkowa;

----------------------------------------------------------------------
-- 6. WYMIAR CZASU – GENEROWANY NA PODSTAWIE REZERWACJI
----------------------------------------------------------------------

INSERT INTO DIM_CZAS (
    Dzien, Miesiac, Kwartal, Rok,
    DzienTygodnia, CzyWeekend, LiczbaNocy
)
SELECT DISTINCT
    CAST(strftime('%d', DataPrzyjazdu) AS INTEGER),
    CAST(strftime('%m', DataPrzyjazdu) AS INTEGER),
    ((CAST(strftime('%m', DataPrzyjazdu) AS INTEGER) - 1) / 3) + 1,
    CAST(strftime('%Y', DataPrzyjazdu) AS INTEGER),
    ((CAST(strftime('%w', DataPrzyjazdu) AS INTEGER) + 6) % 7) + 1,
    CASE WHEN strftime('%w', DataPrzyjazdu) IN ('0', '6') THEN 1 ELSE 0 END,
    CAST(julianday(DataWyjazdu) - julianday(DataPrzyjazdu) AS INTEGER)
FROM hotel.Rezerwacja;

----------------------------------------------------------------------
-- 7. FAKT_REZERWACJA
----------------------------------------------------------------------

INSERT INTO FAKT_REZERWACJA (
    KlientID, HotelID, PokojID, CzasID, LiczbaRezerwacji
)
SELECT
    r.KlientID,
    p.HotelID,
    r.PokojID,
    c.CzasID,
    COUNT(*) AS LiczbaRezerwacji
FROM hotel.Rezerwacja r
JOIN hotel.Pokoj p
    ON p.PokojID = r.PokojID
JOIN DIM_CZAS c
    ON c.Dzien  = CAST(strftime('%d', r.DataPrzyjazdu) AS INTEGER)
   AND c.Miesiac = CAST(strftime('%m', r.DataPrzyjazdu) AS INTEGER)
   AND c.Rok     = CAST(strftime('%Y', r.DataPrzyjazdu) AS INTEGER)
GROUP BY
    r.KlientID, p.HotelID, r.PokojID, c.CzasID;

----------------------------------------------------------------------
-- 8. FAKT_TRANSAKCJA
----------------------------------------------------------------------

INSERT INTO FAKT_TRANSAKCJA (
    KlientID, HotelID, CzasID, UslugaID, LiczbaTransakcji
)
SELECT
    r.KlientID,
    p.HotelID,
    c.CzasID,
    u.UslugaID,
    COUNT(*) AS LiczbaTransakcji
FROM platnosci.UslugaDodatkowa u
JOIN hotel.Rezerwacja r
    ON u.RezerwacjaID = r.RezerwacjaID
JOIN hotel.Pokoj p
    ON r.PokojID = p.PokojID
JOIN DIM_CZAS c
    ON c.Dzien  = CAST(strftime('%d', r.DataPrzyjazdu) AS INTEGER)
   AND c.Miesiac = CAST(strftime('%m', r.DataPrzyjazdu) AS INTEGER)
   AND c.Rok     = CAST(strftime('%Y', r.DataPrzyjazdu) AS INTEGER)
GROUP BY
    r.KlientID, p.HotelID, c.CzasID, u.UslugaID;

----------------------------------------------------------------------
-- 9. ODŁĄCZENIE BAZ
----------------------------------------------------------------------

DETACH DATABASE hotel;
DETACH DATABASE platnosci;

