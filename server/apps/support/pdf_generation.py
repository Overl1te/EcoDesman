from __future__ import annotations

from io import BytesIO
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    ListFlowable,
    ListItem,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

_FONTS_REGISTERED = False

PDF_LABELS = {
    "footer_title": "ЭкоВыхухоль | юридический документ",
    "page": "Страница",
    "status": "Статус",
    "revision": "Редакция",
    "effective_date": "Дата редакции",
    "approved_by": "Оператор",
    "approved_role": "Статус лица",
    "approval_basis": "Основание утверждения",
    "contact": "Контакты",
    "note": "Примечание",
    "quick": "Кратко",
    "withdrawal": "Как отозвать согласие",
    "operator_details": "Реквизиты оператора",
    "generated": "Документ сформирован динамически из единого серверного источника ЭкоВыхухоль.",
    "subject": "Юридические документы ЭкоВыхухоль",
}


def register_fonts() -> None:
    global _FONTS_REGISTERED
    if _FONTS_REGISTERED:
        return

    candidates = [
        ("EcoSans", Path("C:/Windows/Fonts/arial.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")),
        (
            "EcoSans",
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"),
            Path("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"),
        ),
    ]
    for font_name, regular_path, bold_path in candidates:
        if regular_path.exists() and bold_path.exists():
            pdfmetrics.registerFont(TTFont(font_name, str(regular_path)))
            pdfmetrics.registerFont(TTFont(f"{font_name}-Bold", str(bold_path)))
            _FONTS_REGISTERED = True
            return
    raise FileNotFoundError("Не найден TTF-шрифт с поддержкой кириллицы")


def build_styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "title",
            parent=base["Title"],
            fontName="EcoSans-Bold",
            fontSize=20,
            leading=24,
            textColor=colors.HexColor("#143125"),
            spaceAfter=8,
            alignment=TA_LEFT,
        ),
        "subtitle": ParagraphStyle(
            "subtitle",
            parent=base["BodyText"],
            fontName="EcoSans",
            fontSize=10.5,
            leading=14,
            textColor=colors.HexColor("#375348"),
            spaceAfter=12,
        ),
        "heading": ParagraphStyle(
            "heading",
            parent=base["Heading2"],
            fontName="EcoSans-Bold",
            fontSize=12.5,
            leading=16,
            textColor=colors.HexColor("#183629"),
            spaceAfter=6,
            spaceBefore=8,
        ),
        "body": ParagraphStyle(
            "body",
            parent=base["BodyText"],
            fontName="EcoSans",
            fontSize=10.4,
            leading=15,
            textColor=colors.HexColor("#24372f"),
            spaceAfter=7,
        ),
        "meta": ParagraphStyle(
            "meta",
            parent=base["BodyText"],
            fontName="EcoSans",
            fontSize=8.8,
            leading=11,
            textColor=colors.HexColor("#4f645c"),
        ),
    }


def on_page(canvas, doc) -> None:
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#d5dfd8"))
    canvas.line(18 * mm, 14 * mm, 192 * mm, 14 * mm)
    canvas.setFont("EcoSans", 8)
    canvas.setFillColor(colors.HexColor("#5a6c64"))
    canvas.drawString(18 * mm, 9 * mm, PDF_LABELS["footer_title"])
    canvas.drawRightString(192 * mm, 9 * mm, f'{PDF_LABELS["page"]} {canvas.getPageNumber()}')
    canvas.restoreState()


def build_approval_table(approval: dict, styles: dict[str, ParagraphStyle]) -> Table:
    rows = [
        (PDF_LABELS["status"], approval["status"]),
        (PDF_LABELS["revision"], approval["revision"]),
        (PDF_LABELS["effective_date"], approval["effective_date"]),
        (PDF_LABELS["approved_by"], approval["approved_by"]),
        (PDF_LABELS["approved_role"], approval["approved_role"]),
        (PDF_LABELS["approval_basis"], approval["approval_basis"]),
        (PDF_LABELS["contact"], approval["contact"]),
        (PDF_LABELS["note"], approval["note"]),
    ]
    table = Table(
        [
            [
                Paragraph(f"<b>{escape(label)}</b>", styles["meta"]),
                Paragraph(escape(value), styles["meta"]),
            ]
            for label, value in rows
        ],
        colWidths=[48 * mm, 122 * mm],
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#eef4ef")),
                ("BOX", (0, 0), (-1, -1), 0.8, colors.HexColor("#cad8cc")),
                ("INNERGRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#dbe5de")),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 7),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 7),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ]
        )
    )
    return table


def _bullet_list(items: list[str], styles: dict[str, ParagraphStyle]) -> ListFlowable:
    return ListFlowable(
        [ListItem(Paragraph(escape(item), styles["body"])) for item in items],
        bulletType="bullet",
        leftIndent=18,
    )


def build_story(document: dict, styles: dict[str, ParagraphStyle]) -> list:
    story = [
        Paragraph(escape(document["label"]), styles["title"]),
        Paragraph(escape(document["summary"]), styles["subtitle"]),
        build_approval_table(document["approval"], styles),
        Spacer(1, 10),
    ]
    quick_facts = document.get("quick_facts") or []
    if quick_facts:
        story.append(Paragraph(PDF_LABELS["quick"], styles["heading"]))
        story.append(
            ListFlowable(
                [
                    ListItem(
                        Paragraph(
                            f"<b>{escape(item['label'])}:</b> {escape(item['value'])}",
                            styles["body"],
                        )
                    )
                    for item in quick_facts
                ],
                bulletType="bullet",
                leftIndent=18,
            )
        )
        story.append(Spacer(1, 6))
    for section in document["sections"]:
        story.append(Paragraph(escape(section["title"]), styles["heading"]))
        for paragraph in section["paragraphs"]:
            story.append(Paragraph(escape(paragraph), styles["body"]))
        bullets = section.get("bullets") or []
        if bullets:
            story.append(_bullet_list(bullets, styles))
            story.append(Spacer(1, 6))
    withdrawal = document.get("withdrawal") or {}
    if withdrawal.get("items"):
        story.append(Paragraph(PDF_LABELS["withdrawal"], styles["heading"]))
        story.append(_bullet_list(withdrawal["items"], styles))
        story.append(Spacer(1, 6))
    operator = document.get("operator_details") or {}
    if operator:
        story.append(Paragraph(PDF_LABELS["operator_details"], styles["heading"]))
        for label, value in (
            ("Оператор", operator.get("name")),
            ("Статус", operator.get("status")),
            ("ИНН", operator.get("inn")),
            ("ОГРН", operator.get("ogrn")),
            ("Адрес", operator.get("address")),
            ("Телефон", operator.get("phone")),
            ("Email", operator.get("email")),
            ("Сайт", operator.get("website")),
        ):
            if value:
                story.append(Paragraph(f"<b>{escape(label)}:</b> {escape(value)}", styles["body"]))
    story.append(Paragraph(PDF_LABELS["generated"], styles["meta"]))
    return story


def generate_legal_document_pdf(document: dict) -> bytes:
    register_fonts()
    styles = build_styles()
    buffer = BytesIO()
    pdf = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=20 * mm,
        title=document["label"],
        author=document["approval"]["approved_by"],
        subject=PDF_LABELS["subject"],
    )
    pdf.build(
        build_story(document, styles),
        onFirstPage=on_page,
        onLaterPages=on_page,
    )
    return buffer.getvalue()
