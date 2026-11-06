#!/usr/bin/env python3
"""Convierte los WAV de audio/ a OGG Vorbis listos para el juego.

- Efectos cortos: quita el silencio del principio y del final y añade un fundido mínimo.
- Bucles, ambientes y música: se dejan enteros (para no romper el bucle).
- Todo se normaliza a un volumen parecido (RMS) sin pasar de -1 dB de pico.

Uso:  python3 tools/convert_audio.py            (convierte y borra los WAV)
      python3 tools/convert_audio.py --keep     (conserva los WAV)
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "audio"

LOOPS = {
    "perro_jadeo", "perrera_coro", "gato_ronroneo", "cascos_tierra", "patas_suelo",
    "bici_rodando", "coche_ralenti", "coche_marcha", "furgoneta_diesel", "remolque_traqueteo",
    "trafico_lejano", "manguera", "secador", "martillo_obra", "clinica_monitor",
    "oficina_ambiente", "murmullo_gente",
}


def kind(path: pathlib.Path) -> str:
    folder = path.parent.name.lower()
    if folder.startswith("m") and "sica" in folder:
        return "music"
    if folder.startswith("ambiente") or path.stem in LOOPS:
        return "loop"
    return "sfx"


TARGET = {"sfx": -20.0, "loop": -24.0, "music": -18.0}
QUALITY = {"sfx": "4", "loop": "4", "music": "5"}


def levels(path: pathlib.Path, filters: str) -> tuple[float, float]:
    args = ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path)]
    args += ["-af", (filters + "," if filters else "") + "volumedetect", "-f", "null", "-"]
    out = subprocess.run(args, capture_output=True, text=True).stderr
    mean = float(re.search(r"mean_volume: (-?[\d.]+) dB", out).group(1))
    peak = float(re.search(r"max_volume: (-?[\d.]+) dB", out).group(1))
    return mean, peak


def convert(path: pathlib.Path) -> None:
    k = kind(path)
    filters = ""
    if k == "sfx":
        trim = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.01"
        filters = f"{trim},areverse,{trim},areverse"
    mean, peak = levels(path, filters)
    gain = min(TARGET[k] - mean, -1.0 - peak)
    chain = ([filters] if filters else []) + [f"volume={gain:.2f}dB"]
    if k == "sfx":
        chain += ["afade=t=in:d=0.005", "areverse", "afade=t=in:d=0.03", "areverse"]
    out = path.with_suffix(".ogg")
    subprocess.run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(path),
                    "-af", ",".join(chain), "-ar", "44100", "-c:a", "libvorbis", "-q:a", QUALITY[k], str(out)],
                   check=True)
    print(f"{k:5} {gain:+6.1f} dB  {out.relative_to(ROOT)}")


def main() -> None:
    keep = "--keep" in sys.argv
    for wav in sorted(ROOT.rglob("*.wav")):
        convert(wav)
        if not keep:
            wav.unlink()


if __name__ == "__main__":
    main()
