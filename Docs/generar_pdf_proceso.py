#!/usr/bin/env python3
from pathlib import Path
import textwrap


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "proceso_creacion_videojuego.pdf"
CAPTURES = ROOT / "capturas"
PAGE_W = 595
PAGE_H = 842
MARGIN = 54


def pdf_escape(text):
    return text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def to_pdf_text(text):
    return pdf_escape(text).encode("cp1252", errors="replace").decode("cp1252")


def jpg_size(path):
    data = path.read_bytes()
    index = 2
    while index < len(data):
        if data[index] != 0xFF:
            index += 1
            continue
        marker = data[index + 1]
        index += 2
        if marker in (0xD8, 0xD9):
            continue
        length = int.from_bytes(data[index:index + 2], "big")
        if marker in (0xC0, 0xC2):
            height = int.from_bytes(data[index + 3:index + 5], "big")
            width = int.from_bytes(data[index + 5:index + 7], "big")
            return width, height
        index += length
    raise ValueError(f"No se pudo leer el tamaño de {path}")


class Pdf:
    def __init__(self):
        self.objects = []
        self.pages = []
        self.font_obj = self.add_object("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")

    def add_object(self, content):
        self.objects.append(content)
        return len(self.objects)

    def add_stream(self, dictionary, data):
        if isinstance(data, str):
            data = data.encode("cp1252", errors="replace")
        content = f"{dictionary}\nstream\n".encode("ascii") + data + b"\nendstream"
        self.objects.append(content)
        return len(self.objects)

    def image_object(self, path):
        width, height = jpg_size(path)
        data = path.read_bytes()
        dictionary = (
            f"<< /Type /XObject /Subtype /Image /Width {width} /Height {height} "
            f"/ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {len(data)} >>"
        )
        return self.add_stream(dictionary, data), width, height

    def add_page(self, lines, image_path=None, caption=None):
        image_ref = None
        image_w = image_h = 0
        if image_path is not None:
            image_ref, image_w, image_h = self.image_object(image_path)

        ops = []
        y = PAGE_H - MARGIN
        for kind, text in lines:
            if kind == "title":
                size = 21
                leading = 28
            elif kind == "heading":
                size = 15
                leading = 22
            else:
                size = 10.5
                leading = 15

            width = 46 if kind == "body" else 58
            for part in textwrap.wrap(text, width=width) or [""]:
                ops.append(f"BT /F1 {size} Tf {MARGIN} {y:.2f} Td ({to_pdf_text(part)}) Tj ET")
                y -= leading
            y -= 4 if kind != "body" else 1

        if image_ref is not None:
            max_w = PAGE_W - MARGIN * 2
            max_h = min(430, y - 86)
            scale = min(max_w / image_w, max_h / image_h)
            draw_w = image_w * scale
            draw_h = image_h * scale
            x = (PAGE_W - draw_w) / 2
            y_img = max(82, y - draw_h - 12)
            ops.append("q")
            ops.append(f"{draw_w:.2f} 0 0 {draw_h:.2f} {x:.2f} {y_img:.2f} cm /Im1 Do")
            ops.append("Q")
            if caption:
                ops.append(f"BT /F1 9 Tf {MARGIN} {y_img - 18:.2f} Td ({to_pdf_text(caption)}) Tj ET")

        resources = f"<< /Font << /F1 {self.font_obj} 0 R >>"
        if image_ref is not None:
            resources += f" /XObject << /Im1 {image_ref} 0 R >>"
        resources += " >>"

        content_ref = self.add_stream(f"<< /Length {len(chr(10).join(ops).encode('cp1252', errors='replace'))} >>", "\n".join(ops))
        page_ref = self.add_object(
            f"<< /Type /Page /Parent {{pages}} 0 R /MediaBox [0 0 {PAGE_W} {PAGE_H}] "
            f"/Resources {resources} /Contents {content_ref} 0 R >>"
        )
        self.pages.append(page_ref)

    def write(self, path):
        pages_ref = len(self.objects) + 1
        kids = " ".join(f"{page} 0 R" for page in self.pages)
        self.add_object(f"<< /Type /Pages /Kids [{kids}] /Count {len(self.pages)} >>")
        catalog_ref = self.add_object(f"<< /Type /Catalog /Pages {pages_ref} 0 R >>")

        output = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        offsets = [0]
        for index, obj in enumerate(self.objects, start=1):
            offsets.append(len(output))
            if isinstance(obj, str):
                obj = obj.replace("{pages}", str(pages_ref)).encode("cp1252", errors="replace")
            output.extend(f"{index} 0 obj\n".encode("ascii"))
            output.extend(obj)
            output.extend(b"\nendobj\n")

        xref = len(output)
        output.extend(f"xref\n0 {len(self.objects) + 1}\n".encode("ascii"))
        output.extend(b"0000000000 65535 f \n")
        for offset in offsets[1:]:
            output.extend(f"{offset:010d} 00000 n \n".encode("ascii"))
        output.extend(
            f"trailer\n<< /Size {len(self.objects) + 1} /Root {catalog_ref} 0 R >>\n"
            f"startxref\n{xref}\n%%EOF\n".encode("ascii")
        )
        path.write_bytes(output)


def page(title, paragraphs, image=None, caption=None):
    lines = [("heading", title)]
    lines.extend(("body", paragraph) for paragraph in paragraphs)
    return lines, image, caption


def main():
    pdf = Pdf()
    pdf.add_page([
        ("title", "Proceso de creacion del videojuego Doodle Developer"),
        ("body", "Proyecto final del ciclo de Desarrollo de Aplicaciones Multiplataforma."),
        ("body", "Motor: Godot 4.6.2. Plataforma objetivo inicial: Android. Orientacion: vertical. Resolucion base: 720 x 1280."),
        ("body", "Este documento resume la creacion del prototipo, sus mecanicas principales y las mejoras realizadas durante las pruebas en movil."),
    ], CAPTURES / "01_menu.jpg", "Captura 1. Menu principal del prototipo.")

    sections = [
        page("Arquitectura general", [
            "La escena Main.tscn centraliza camara, HUD, menus, audio y contenedor de plataformas.",
            "Player.tscn contiene el jugador con fisica, animacion visual, rebote y envoltura lateral.",
            "Platform.tscn reutiliza una unica escena para plataformas normales, moviles y rompibles.",
            "La logica se reparte entre game.gd, player.gd y platform.gd para mantener responsabilidades separadas.",
        ], CAPTURES / "02_gameplay.jpg", "Captura 2. Gameplay con camara ascendente, plataformas y HUD."),
        page("Mecanicas implementadas", [
            "El jugador salta automaticamente al aterrizar sobre una plataforma. La puntuacion aumenta con la altura maxima alcanzada.",
            "Las plataformas normales rebotan de forma estandar. Las moviles cambian el ritmo del salto. Las rompibles permiten un rebote y despues se destruyen.",
            "Se incorporaron sonidos diferentes por tipo de plataforma para mejorar la respuesta del juego.",
        ], CAPTURES / "02_gameplay.jpg", "Captura 3. Plataformas distribuidas durante la partida."),
        page("Mejora del control tactil", [
            "La primera version usaba zonas tactiles invisibles a izquierda y derecha. Funcionaba, pero era poco precisa.",
            "La mejora actual usa un slider invisible: al tocar la pantalla se crea un centro, y el desplazamiento horizontal del dedo se transforma en direccion e intensidad.",
            "Si el dedo se mueve hacia la izquierda, el jugador se mueve a la izquierda. Si vuelve cerca del punto inicial, se detiene.",
            "Esta solucion evita botones visibles y permite un control mas progresivo en movil.",
        ], CAPTURES / "03_control_slider_invisible.jpg", "Captura 4. Prueba del control tactil con slider invisible."),
        page("Viewport adaptado a dispositivos moviles", [
            "En pruebas se detecto que el fondo estaba fijo a 720 x 1280 y en pantallas mas altas aparecia una franja gris.",
            "Se cambio el fondo para que se ancle a pantalla completa y se actualizo la logica para usar el viewport real.",
            "La camara, el ancho de envoltura del jugador, el spawn y la limpieza de plataformas se calculan con el tamano real visible.",
        ], CAPTURES / "02_gameplay.jpg", "Captura 5. Fondo ocupando toda la vista del juego."),
        page("Pausa, configuracion y audio", [
            "El boton de pausa detiene la partida, la fisica, la camara y los controles.",
            "La configuracion incluye volumen de musica y volumen de efectos.",
            "Durante pruebas se subio el volumen base de la musica porque al 100% se escuchaba demasiado bajo.",
        ], CAPTURES / "04_pausa.jpg", "Captura 6. Panel de pausa durante gameplay."),
        page("Configuracion de audio", [
            "El menu de configuracion permite ajustar musica y efectos sin salir del juego.",
            "Esta parte se dejo sencilla para mantener el foco en la jugabilidad y poder mejorar la presentacion mas adelante.",
        ], CAPTURES / "05_configuracion_audio.jpg", "Captura 7. Pantalla de configuracion de audio."),
        page("Game Over y exportacion Android", [
            "La pantalla de Game Over muestra puntuacion final, record de la sesion, reintento y regreso al menu principal.",
            "Se instalaron las export templates de Godot 4.6.2 y se configuro Android SDK, JDK y debug keystore.",
            "El APK Debug se genero en builds/DoodleDeveloper-debug.apk con paquete com.doodledeveloper.game.",
        ], CAPTURES / "06_game_over_record.jpg", "Captura 8. Pantalla de Game Over con record."),
        page("Conclusion", [
            "El prototipo ya cuenta con salto automatico, plataformas infinitas, variantes de plataforma, HUD, pausa, configuracion, audio, animacion, Game Over, viewport adaptable y exportacion Android.",
            "Las mejoras con mayor impacto han sido el viewport adaptado a pantallas moviles y el control tactil basado en slider invisible.",
            "El documento queda preparado como base tecnica para ampliarlo y maquetarlo en una sesion posterior.",
        ]),
    ]

    for lines, image, caption in sections:
        pdf.add_page(lines, image, caption)
    pdf.write(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
