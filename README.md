# Laborprotokoll: Middleware Engineering

**Thema:** CI/CD Pipelines mit Jenkins & Docker

**Schüler:** Daniel Ofosuhene

**Klasse:** 4CHIT

**Datum:** 25. Mai 2026

---

## 1. Aufgabenstellung & Zielsetzung

Das Ziel dieser Übung war der Aufbau einer automatisierten **CI/CD-Pipeline** (Continuous Integration / Continuous Deployment) unter Verwendung von **Jenkins**. Dabei sollte eine Python-basierte API (Flask) automatisch aus einem GitHub-Repository bezogen, in einer isolierten Docker-Umgebung gebaut, getestet und lokal bereitgestellt werden.

---

## 2. Theoretische Grundlagen

### CI/CD Pipeline

* **Continuous Integration (CI):** Automatisches Zusammenführen von Code-Änderungen, gefolgt von Builds und Tests, um die Softwarequalität sicherzustellen.
* **Continuous Delivery (CD):** Die automatisierte Bereitstellung der Software in einer Test- oder Produktionsumgebung.

### Jenkins & Docker-Agents

In dieser Übung wurde Jenkins nicht nur als Steuerungseinheit genutzt, sondern auch als Orchestrator für Docker. Durch die Verwendung von **Docker-Agents** im Jenkinsfile wird sichergestellt, dass der Build-Prozess in einer exakt definierten Umgebung (hier `python:3.11`) stattfindet, unabhängig vom Host-System.

---

## 3. Durchführung & Systemkonfiguration (Mac/macOS)

Da ich die Übung auf einem **macOS-System** durchgeführt habe, waren folgende Konfigurationsschritte notwendig:

1. **Infrastruktur:** Start des Jenkins-Containers mit Volume-Mounting für den Docker-Socket (`/var/run/docker.sock`). Dies erlaubt "Docker-in-Docker"-Befehle.
2. **Plugin-Management:** Installation des **"Docker Pipeline" Plugins** in Jenkins, um den `agent { docker { ... } }` Block im Jenkinsfile nutzen zu können.
3. **Berechtigungsmanagement:** Innerhalb des Jenkins-Containers wurde die Docker-CLI nachinstalliert und der Zugriff auf den Socket sichergestellt.

---

## 4. Pipeline-Struktur (Jenkinsfile)

Die Pipeline wurde als **Declarative Pipeline** realisiert und umfasst folgende Phasen:

* **Pre-Build Cleanup:** Bereinigung alter Prozesse mittels `pkill`, um Port-Konflikte (Port 5556) zu vermeiden.
* **Checkout:** Automatischer Klon des Repositories von GitHub (`DEZSYS_JENKINS_HELLOSPENCER`).
* **Build:** Installation der notwendigen Python-Libraries (`Flask`, `pytest`, `requests`) im Agent-Container.
* **Test:** Ausführung von Unit-Tests (`pytest`), um die Integrität der `hello.py` Logik zu prüfen.
* **Run & API-Test:** Start der Flask-App im Hintergrund und Validierung der Schnittstelle mittels `curl` und einem dedizierten API-Test-Script.

---

## 5. Ergebnisse & Fehleranalyse

Die Pipeline wurde erfolgreich durchlaufen. Die API antwortete korrekt mit dem JSON-Body:
`{ "counter": X, "message": "Hello Spencer", "status": "success" }`

**Herausforderungen während der Umsetzung:**

* **Fehler:** `Invalid agent type "docker"`.
* **Lösung:** Installation des fehlenden Docker-Pipeline-Plugins.


* **Fehler:** `Permission Denied` beim Schreiben der `count.txt`.
* **Lösung:** Anpassung der Agent-Argumente auf `-u root` im Jenkinsfile, um Schreibrechte innerhalb des gemounteten Workspaces zu erhalten.



