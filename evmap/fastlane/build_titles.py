#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate screenshot title strings for every App Store language.
Run from evmap/fastlane/:  python3 build_titles.py
Writes frameit/<locale>/title.strings, keyed by screenshot token
(01Map / 02StationDetail / 03Filter).
Norwegian is captured as "nb" (iOS) and delivered as "no" (ASC).
"""
import os

HERE = os.path.dirname(__file__)
OUT = os.path.join(HERE, "frameit")

# locale -> (01Map, 02StationDetail, 03Filter)
TITLES = {
    "en-US": (
        "All charging stations at a glance",
        "Real-time availability & details",
        "Find exactly what you need",
    ),
    "de-DE": (
        "Alle Ladestationen auf einen Blick",
        "Echtzeit-Verfügbarkeit & Details",
        "Finde genau das Richtige",
    ),
    "fr-FR": (
        "Toutes les bornes en un coup d'œil",
        "Disponibilité en temps réel & détails",
        "Trouvez exactement ce qu'il vous faut",
    ),
    "it": (
        "Tutte le stazioni in un colpo d'occhio",
        "Disponibilità in tempo reale & dettagli",
        "Trova esattamente ciò che cerchi",
    ),
    "nl-NL": (
        "Alle laadstations in één oogopslag",
        "Realtime beschikbaarheid & details",
        "Vind precies wat je zoekt",
    ),
    "pt-PT": (
        "Todas as estações num relance",
        "Disponibilidade em tempo real & detalhes",
        "Encontra exatamente o que precisas",
    ),
    "sv": (
        "Alla laddstationer i ett ögonkast",
        "Realtidsstatus & detaljer",
        "Hitta precis vad du behöver",
    ),
    "nb": (
        "Alle ladestasjoner på ett blikk",
        "Sanntidsstatus & detaljer",
        "Finn nøyaktig det du trenger",
    ),
    "no": (
        "Alle ladestasjoner på ett blikk",
        "Sanntidsstatus & detaljer",
        "Finn nøyaktig det du trenger",
    ),
    "cs": (
        "Všechny nabíjecí stanice na jeden pohled",
        "Dostupnost v reálném čase & detaily",
        "Najdi přesně to, co potřebuješ",
    ),
    "ro": (
        "Toate stațiile de încărcare dintr-o privire",
        "Disponibilitate în timp real & detalii",
        "Găsește exact ce ai nevoie",
    ),
    "es-ES": (
        "Todas las estaciones de carga de un vistazo",
        "Disponibilidad en tiempo real & detalles",
        "Encuentra exactamente lo que necesitas",
    ),
}


def main():
    for loc, (t1, t2, t3) in TITLES.items():
        d = os.path.join(OUT, loc)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, "title.strings"), "w", encoding="utf-8") as f:
            f.write(f'"01Map" = "{t1}";\n')
            f.write(f'"02StationDetail" = "{t2}";\n')
            f.write(f'"03Filter" = "{t3}";\n')
        print("wrote", loc)


if __name__ == "__main__":
    main()
