import os
from datetime import datetime
import html

def unfold_lines(lines):
    unfolded = []
    buffer = ""

    for line in lines:
        if line.startswith(" ") or line.startswith("\t"):
            buffer += line[1:]
        else:
            if buffer:
                unfolded.append(buffer)
            buffer = line
    if buffer:
        unfolded.append(buffer)

    return unfolded

def parse_datetime(value, is_date_only=False):
    if is_date_only:
        try:
            dt = datetime.strptime(value, "%Y%m%d")
            return dt, dt.strftime("%d/%m/%Y")
        except ValueError:
            return None, value

    formats = [
        "%Y%m%dT%H%M%SZ",
        "%Y%m%dT%H%M%S",
        "%Y%m%dT%H%M",
    ]
    for fmt in formats:
        try:
            dt = datetime.strptime(value, fmt)
            return dt, dt.strftime("%d/%m/%Y %H:%M")
        except ValueError:
            pass

    return None, value

def parse_ics(path):
    with open(path, "r", encoding="utf-8") as f:
        lines = unfold_lines([l.rstrip("\n") for l in f])

    events = []
    current_dt = None
    current_dt_str = None
    current_summary = ""

    inside_event = False

    for line in lines:

        if line == "BEGIN:VEVENT":
            inside_event = True
            current_dt = None
            current_dt_str = None
            current_summary = ""
            continue

        if line == "END:VEVENT":
            if current_dt:
                events.append((current_dt, current_dt_str, current_summary.strip()))
            inside_event = False
            continue

        if not inside_event:
            continue

        if line.startswith("DTSTART"):
            if ";VALUE=DATE:" in line:
                raw = line.split(":")[1]
                current_dt, current_dt_str = parse_datetime(raw, is_date_only=True)
            else:
                raw = line.split(":", 1)[1]
                current_dt, current_dt_str = parse_datetime(raw)

        elif line.startswith("SUMMARY:"):
            current_summary = line.split(":", 1)[1]

    events.sort(key=lambda x: x[0])
    return events

def generate_csv(all_events, csv_path):
    with open(csv_path, "w", encoding="utf-8") as f:
        f.write("FILE,MESE,ANNO,DATA,SUMMARY\n")
        for prefix, mese_nome, anno, data_senza_orario, summary in all_events:
            summary_csv = summary.replace(",", " ")
            f.write(f"{prefix},{mese_nome},{anno},{data_senza_orario},{summary_csv}\n")

def generate_html(all_events, html_path):
    files = sorted({e[0] for e in all_events})
    mesi = sorted({e[1] for e in all_events})
    anni = sorted({e[2] for e in all_events})

    with open(html_path, "w", encoding="utf-8") as f:
        f.write("""<!DOCTYPE html>
<html lang="it">
<head>
<meta charset="UTF-8">
<title>Tutti gli eventi</title>
<style>
body { font-family: Arial, sans-serif; margin: 20px; }
label { margin-right: 10px; }
select { margin-right: 20px; }
table { border-collapse: collapse; width: 100%; margin-top: 15px; }
th, td { border: 1px solid #ccc; padding: 6px 8px; font-size: 14px; }
th { background-color: #f0f0f0; }
tr.hidden { display: none; }
</style>
</head>
<body>
<h2>Tutti gli eventi</h2>

<div>
  <label for="filtroFile">File:</label>
  <select id="filtroFile">
    <option value="">(Tutti)</option>
""")
        for val in files:
            f.write(f'    <option value="{html.escape(val)}">{html.escape(val)}</option>\n')

        f.write("""  </select>

  <label for="filtroMese">Mese:</label>
  <select id="filtroMese">
    <option value="">(Tutti)</option>
""")
        for val in mesi:
            f.write(f'    <option value="{html.escape(val)}">{html.escape(val)}</option>\n')

        f.write("""  </select>

  <label for="filtroAnno">Anno:</label>
  <select id="filtroAnno">
    <option value="">(Tutti)</option>
""")
        for val in anni:
            f.write(f'    <option value="{val}">{val}</option>\n')

        f.write("""  </select>
</div>

<table id="tabellaEventi">
  <thead>
    <tr>
      <th>File</th>
      <th>Mese</th>
      <th>Anno</th>
      <th>Data</th>
      <th>Summary</th>
    </tr>
  </thead>
  <tbody>
""")

        for prefix, mese_nome, anno, data_senza_orario, summary in all_events:
            f.write(
                "    <tr data-file=\"{file}\" data-mese=\"{mese}\" data-anno=\"{anno}\">"
                "<td>{file}</td><td>{mese}</td><td>{anno}</td><td>{data}</td><td>{summary}</td></tr>\n".format(
                    file=html.escape(prefix),
                    mese=html.escape(mese_nome),
                    anno=anno,
                    data=html.escape(data_senza_orario),
                    summary=html.escape(summary),
                )
            )

        f.write("""  </tbody>
</table>

<script>
const filtroFile = document.getElementById('filtroFile');
const filtroMese = document.getElementById('filtroMese');
const filtroAnno = document.getElementById('filtroAnno');
const rows = Array.from(document.querySelectorAll('#tabellaEventi tbody tr'));

function applicaFiltri() {
  const fileVal = filtroFile.value;
  const meseVal = filtroMese.value;
  const annoVal = filtroAnno.value;

  rows.forEach(row => {
    const rFile = row.getAttribute('data-file');
    const rMese = row.getAttribute('data-mese');
    const rAnno = row.getAttribute('data-anno');

    let visibile = true;
    if (fileVal && rFile !== fileVal) visibile = false;
    if (meseVal && rMese !== meseVal) visibile = false;
    if (annoVal && rAnno !== annoVal) visibile = false;

    row.style.display = visibile ? '' : 'none';
  });
}

filtroFile.addEventListener('change', applicaFiltri);
filtroMese.addEventListener('change', applicaFiltri);
filtroAnno.addEventListener('change', applicaFiltri);
</script>

</body>
</html>
""")

def process_all_ics():
    files = [f for f in os.listdir(".") if f.lower().endswith(".ics") or f.lower().endswith(".txt")]

    if not files:
        print("Nessun file .ics trovato nella cartella.")
        return

    all_events = []

    for ics in files:
        prefix = os.path.splitext(ics)[0].split("_")[0]
        events = parse_ics(ics)

        for dt, date_str, summary in events:
            mese_nome = dt.strftime("%B").capitalize()
            anno = dt.year
            data_senza_orario = dt.strftime("%d/%m/%Y")
            all_events.append((prefix, mese_nome, anno, data_senza_orario, summary))

    all_events.sort(key=lambda x: (x[2], x[1], x[3], x[0]))

    generate_csv(all_events, "TUTTI_EVENTI.csv")
    generate_html(all_events, "TUTTI_EVENTI.html")

    print("Creati: TUTTI_EVENTI.csv e TUTTI_EVENTI.html")

if __name__ == "__main__":
    process_all_ics()
