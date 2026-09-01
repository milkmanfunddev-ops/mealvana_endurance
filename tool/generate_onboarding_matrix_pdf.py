#!/usr/bin/env python3
"""Generate the one-page onboarding API coverage matrix."""

from pathlib import Path
import sys

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "output" / "pdf" / "onboarding-matrix.pdf"


def _font(name: str, fallback: str) -> str:
    candidates = {
        "regular": [
            ROOT / "assets" / "fonts" / "Apercu-Regular.ttf",
            Path("/System/Library/Fonts/Supplemental/Arial.ttf"),
        ],
        "bold": [
            ROOT / "assets" / "fonts" / "Apercu-Bold.ttf",
            Path("/System/Library/Fonts/Supplemental/Arial Bold.ttf"),
        ],
    }
    for path in candidates[name]:
        if path.exists():
            registered = f"OnboardingMatrix-{name}"
            pdfmetrics.registerFont(TTFont(registered, str(path)))
            return registered
    return fallback


REGULAR = _font("regular", "Helvetica")
BOLD = _font("bold", "Helvetica-Bold")

INK = colors.HexColor("#17202A")
MUTED = colors.HexColor("#5E6A75")
TEAL = colors.HexColor("#0E7490")
TEAL_LIGHT = colors.HexColor("#E7F2F5")
GREEN = colors.HexColor("#18743A")
GREEN_LIGHT = colors.HexColor("#EAF5ED")
AMBER = colors.HexColor("#9A5B06")
AMBER_LIGHT = colors.HexColor("#FFF4DD")
NO_LIGHT = colors.HexColor("#F1F3F5")
RULE = colors.HexColor("#DCE2E7")
BLACKBERRY = colors.HexColor("#241A2B")
ORANGE = colors.HexColor("#F7941D")


def p(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text, style)


def coverage(status: str, detail: str, styles: dict[str, ParagraphStyle]) -> Paragraph:
    color = {"YES": GREEN, "PART": AMBER, "NO": MUTED}[status]
    label = f'<font color="{color.hexval()}"><b>{status}</b></font>'
    suffix = f"<br/>{detail}" if detail else ""
    return p(label + suffix, styles["cell"])


def build(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)

    styles = {
        "title": ParagraphStyle(
            "title", fontName=BOLD, fontSize=21, leading=22, textColor=BLACKBERRY, spaceAfter=2
        ),
        "subtitle": ParagraphStyle(
            "subtitle", fontName=REGULAR, fontSize=8.2, leading=10.2, textColor=MUTED
        ),
        "section": ParagraphStyle(
            "section", fontName=BOLD, fontSize=8.2, leading=9.5, textColor=TEAL
        ),
        "head": ParagraphStyle(
            "head", fontName=BOLD, fontSize=6.9, leading=7.7, textColor=colors.white, alignment=TA_LEFT
        ),
        "field": ParagraphStyle(
            "field", fontName=BOLD, fontSize=6.9, leading=7.8, textColor=INK
        ),
        "req": ParagraphStyle(
            "req", fontName=REGULAR, fontSize=6.1, leading=7.1, textColor=MUTED
        ),
        "cell": ParagraphStyle(
            "cell", fontName=REGULAR, fontSize=5.9, leading=6.9, textColor=INK
        ),
        "note": ParagraphStyle(
            "note", fontName=REGULAR, fontSize=6.2, leading=7.5, textColor=MUTED
        ),
        "endpoint": ParagraphStyle(
            "endpoint", fontName=REGULAR, fontSize=6.2, leading=7.4, textColor=INK
        ),
        "footer": ParagraphStyle(
            "footer", fontName=REGULAR, fontSize=5.6, leading=6.7, textColor=MUTED
        ),
    }

    doc = SimpleDocTemplate(
        str(output),
        pagesize=landscape(letter),
        leftMargin=0.34 * inch,
        rightMargin=0.34 * inch,
        topMargin=0.26 * inch,
        bottomMargin=0.24 * inch,
        title="Onboarding Matrix",
        author="Mealvana Endurance",
        subject="Training-platform API coverage for active onboarding fields",
    )

    story = [
        p("ONBOARDING MATRIX", styles["title"]),
        p(
            "API coverage for the active Mealvana Endurance onboarding flow - verified 2026-07-23",
            styles["subtitle"],
        ),
        Spacer(1, 0.09 * inch),
    ]

    headers = [
        p("ONBOARDING FIELD", styles["head"]),
        p("APP VALUE", styles["head"]),
        p("GARMIN", styles["head"]),
        p("TRAININGPEAKS", styles["head"]),
        p("FINAL SURGE", styles["head"]),
        p("VDOT O2", styles["head"]),
        p("RUNNA", styles["head"]),
    ]
    rows = [
        ["First name", "Optional string", ("NO", ""), ("YES", "FirstName"), ("YES", "firstname"), ("NO", ""), ("NO", "")],
        ["Last name", "Optional string", ("NO", ""), ("YES", "LastName"), ("YES", "lastname"), ("NO", ""), ("NO", "")],
        ["Email", "Optional email", ("NO", ""), ("YES", "Email"), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Gender", "Required enum", ("NO", ""), ("PART", "Sex: m/f only"), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Birthday", "Required full date", ("NO", ""), ("PART", "BirthMonth: YYYY-MM"), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Height", "Required cm or ft/in", ("NO", "Pregnancy goal only*"), ("NO", ""), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Weight", "Required kg or lb", ("YES", "weightInGrams"), ("YES", "Weight (kg)"), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Unit system", "Metric / imperial", ("NO", ""), ("YES", "PreferredUnits"), ("NO", ""), ("NO", ""), ("NO", "")],
        [
            "Sports trained",
            "Run / bike / swim",
            ("PART", "Infer activity sport"),
            ("PART", "Infer workouts/zones"),
            ("PART", "Infer workout sport"),
            ("PART", "Infer event type"),
            ("PART", "Running feed"),
        ],
        ["Dietary preference", "Optional enum", ("NO", ""), ("NO", ""), ("NO", ""), ("NO", ""), ("NO", "")],
        ["Allergies", "Optional list", ("NO", ""), ("NO", ""), ("NO", ""), ("NO", ""), ("NO", "")],
    ]

    table_data = [headers]
    status_grid: list[list[str]] = []
    for field, req, garmin, tp, fs, vdot, runna in rows:
        table_data.append(
            [
                p(field, styles["field"]),
                p(req, styles["req"]),
                coverage(*garmin, styles),
                coverage(*tp, styles),
                coverage(*fs, styles),
                coverage(*vdot, styles),
                coverage(*runna, styles),
            ]
        )
        status_grid.append([garmin[0], tp[0], fs[0], vdot[0], runna[0]])

    matrix = Table(
        table_data,
        colWidths=[
            1.05 * inch,
            1.17 * inch,
            1.48 * inch,
            1.53 * inch,
            1.39 * inch,
            1.25 * inch,
            1.17 * inch,
        ],
        rowHeights=[0.28 * inch] + [0.285 * inch] * len(rows),
        repeatRows=1,
    )
    matrix_style = [
        ("BACKGROUND", (0, 0), (-1, 0), BLACKBERRY),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 2),
        ("GRID", (0, 0), (-1, -1), 0.45, RULE),
        ("BACKGROUND", (0, 1), (1, -1), colors.white),
    ]
    cell_background = {"YES": GREEN_LIGHT, "PART": AMBER_LIGHT, "NO": NO_LIGHT}
    for row_index, statuses in enumerate(status_grid, start=1):
        for col_index, status in enumerate(statuses, start=2):
            matrix_style.append(
                ("BACKGROUND", (col_index, row_index), (col_index, row_index), cell_background[status])
            )
    matrix.setStyle(TableStyle(matrix_style))
    story.extend([matrix, Spacer(1, 0.08 * inch)])

    endpoint_data = [
        [
            p("PRIMARY SOURCES", styles["section"]),
            p("<b>Garmin</b> Health body composition push/ping + <font name=\"Courier\">bodyComps</font> endpoint", styles["endpoint"]),
            p("<b>TrainingPeaks</b> <font name=\"Courier\">GET /v1/athlete/profile</font>", styles["endpoint"]),
            p("<b>Final Surge</b> identity in <font name=\"Courier\">POST /oauth/token</font> response", styles["endpoint"]),
            p("<b>VDOT O2</b> no profile endpoint", styles["endpoint"]),
            p("<b>Runna</b> personal iCalendar feed; no profile", styles["endpoint"]),
        ]
    ]
    endpoints = Table(
        endpoint_data,
        colWidths=[1.05 * inch, 1.84 * inch, 1.76 * inch, 1.82 * inch, 1.29 * inch, 1.28 * inch],
    )
    endpoints.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, 0), TEAL_LIGHT),
                ("BOX", (0, 0), (-1, -1), 0.45, RULE),
                ("INNERGRID", (0, 0), (-1, -1), 0.45, RULE),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.extend([endpoints, Spacer(1, 0.06 * inch)])

    notes = Table(
        [
            [
                p(
                    "<b>Current prefill:</b> TrainingPeaks -> name, weight, birth month (day defaults to 1), "
                    "binary gender. Final Surge -> name. Garmin -> weight (preferred when both Garmin and "
                    "TrainingPeaks have it). VDOT O2 and Runna -> none.",
                    styles["note"],
                ),
                p(
                    "<b>Legend:</b> YES = direct semantic match. PART = incomplete or inferred; confirm with "
                    "the user. NO = no onboarding equivalent. *Garmin pregnancy height is not a general "
                    "athlete-height field.",
                    styles["note"],
                ),
            ]
        ],
        colWidths=[4.16 * inch, 4.20 * inch],
    )
    notes.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F8FAFB")),
                ("BOX", (0, 0), (-1, -1), 0.45, RULE),
                ("INNERGRID", (0, 0), (-1, -1), 0.45, RULE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 6),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story.extend(
        [
            notes,
            Spacer(1, 0.06 * inch),
            p(
                "Scope: active onboarding only. Preserved sport-detail screens and the removed food-like "
                "screen are excluded. Full field dictionaries: docs/integration/api-exploration/index.html.",
                styles["footer"],
            ),
        ]
    )

    def page(canvas, _doc):
        canvas.saveState()
        canvas.setFillColor(ORANGE)
        canvas.rect(0, landscape(letter)[1] - 0.08 * inch, landscape(letter)[0], 0.08 * inch, fill=1, stroke=0)
        canvas.restoreState()

    doc.build([KeepTogether(story)], onFirstPage=page)


if __name__ == "__main__":
    target = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_OUTPUT
    build(target)
    print(target)
