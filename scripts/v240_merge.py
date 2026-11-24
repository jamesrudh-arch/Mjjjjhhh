#!/usr/bin/env python3
"""Merge cover + body into the final v2.4.0 report PDF (normalized to A4)."""
from pypdf import PdfReader, PdfWriter

A4_W, A4_H = 595.28, 841.89

def normalize(page):
    box = page.mediabox
    w, h = float(box.width), float(box.height)
    if abs(w - A4_W) > 0.1 or abs(h - A4_H) > 0.1:
        page.scale_to(A4_W, A4_H)
    return page

writer = PdfWriter()
writer.add_page(normalize(PdfReader("/home/z/my-project/scripts/v240_cover.pdf").pages[0]))
for p in PdfReader("/home/z/my-project/scripts/v240_report_body.pdf").pages:
    writer.add_page(normalize(p))
writer.add_metadata({
    "/Title": "LEVERAGE v2.4.0 Full Audit and World-Class Upgrade Report",
    "/Author": "Z.ai",
    "/Creator": "Z.ai",
    "/Subject": "Full audit-test-verify-audit, findings, upgrades and roadmap to 10/10",
})
out = "/home/z/my-project/download/LEVERAGE_v2.4.0_Audit_and_WorldClass_Report.pdf"
with open(out, "wb") as f:
    writer.write(f)
print("MERGED:", out, "pages:", len(writer.pages))
