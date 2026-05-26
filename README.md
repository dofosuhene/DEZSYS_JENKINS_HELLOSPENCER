
# Laborprotokoll: Middleware Engineering
**Thema:** CI/CD Pipelines mit Jenkins & Docker (Erweiterte Anforderungen)  
**Schüler:** Daniel Ofosuhene  
**Klasse:** 4CHIT  
**Datum:** 26. Mai 2026

---

## 1. Aufgabenstellung & Zielsetzung
Das Ziel dieser Übung war der Aufbau einer vollautomatisierten **CI/CD-Pipeline** (Continuous Integration / Continuous Deployment) mit **Jenkins** auf einem macOS-System. Die Pipeline soll eine Python-basierte Flask-API aus einem GitHub-Repository beziehen, in einer isolierten Docker-Umgebung bauen, testen und lokal auf dem Notebook bereitstellen. 

Durch die Umsetzung wurden die erweiterten Kriterien nach Punkt 6.1 und 6.2 zur Gänze erfüllt.

---

## 2. Theoretische Grundlagen

### 2.1 CI/CD Konzepte
* **Continuous Integration (CI):** Entwickler pushen Code-Änderungen in ein zentrales Repository (GitHub). Jenkins holt sich diesen Code automatisch, führt einen Build durch und testet die Software, um Fehler sofort zu isolieren.
* **Continuous Deployment (CD):** Nach erfolgreichem Testlauf wird die Applikation ohne manuelles Eingreifen direkt in die Zielumgebung (lokaler Docker-Container) deployt.

### 2.2 Docker als Build-Agent (Middleware-Infrastruktur)
Anstatt Python direkt auf dem Host-System zu installieren, nutzt Jenkins das Prinzip "Infrastructure as Code". Über das Jenkinsfile wird ein temporärer Docker-Agent (`python:3.11`) gestartet. Dies garantiert eine saubere, reproduzierbare Laufzeitumgebung, die plattformunabhängig funktioniert.

---

## 3. Systemkonfiguration & Durchführung

### 3.1 Docker-Setup auf macOS
Da die Übung auf einem Mac durchgeführt wurde, läuft Jenkins selbst in einem Docker-Container. Um diesem Container zu erlauben, weitere Container zu starten (Docker-in-Docker), wurde der Docker-Socket des Macs übergeben:

```bash
docker run -u root -d \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name jenkins-server \
  jenkins/jenkins:lts

```

### 3.2 Jenkins-Konfiguration & GitHub-Trigger

1. **Plugins:** Es wurde das **"Docker Pipeline" Plugin** installiert, damit Jenkins die `agent { docker }` Syntax versteht. In der Container-Shell wurde zudem die `docker-ce-cli` nachinstalliert.
2. **Automatischer Build-Trigger (Kriterium 6.2):** In den Pipeline-Einstellungen wurde **"Poll SCM"** mit der Cron-Syntax `* * * * *` aktiviert. Jenkins prüft nun jede Minute das GitHub-Repository auf neue Commits und startet die Pipeline bei Änderungen vollautomatisch.

---

## 4. Die Pipeline-Lösung (Jenkinsfile)

Die Pipeline steuert den gesamten Lebenszyklus der Middleware-Applikation in fünf klar definierten Stages:

```groovy
pipeline {
    agent {
        docker { 
            image 'python:3.11' 
            args '-u root' // Verhindert Permission-Probleme auf macOS
        }
    }
    environment {
        APP_PORT = '5556'
        GITHUB_REPO = '[https://github.com/dofosuhene/DEZSYS_JENKINS_HELLOSPENCER.git](https://github.com/dofosuhene/DEZSYS_JENKINS_HELLOSPENCER.git)'
    }
    stages {
        stage('Pre-Build Cleanup') {
            steps {
                // Verhindert Port-Blockaden durch alte Instanzen
                sh 'pkill -f "python src/hello.py" || true'
            }
        }
        stage('Checkout') {
            steps {
                cleanWs() // Workspace leeren
                git branch: 'main', url: "${GITHUB_REPO}"
            }
        }
        stage('Build') {
            steps {
                sh '''
                    python -m pip install --upgrade pip
                    pip install flask requests pytest
                    if [ ! -f count.txt ]; then echo "0" > count.txt; fi
                    chmod 666 count.txt
                '''
            }
        }
        stage('Test') {
            steps {
                // Führt die Unit-Tests inklusive des eigenen Tests aus
                sh 'python -m pytest tests/test_hello.py -v'
            }
        }
        stage('Run & API Test') {
            steps {
                sh '''
                    nohup python src/hello.py > app.log 2>&1 &
                    sleep 5
                    curl http://localhost:5556/api/hello
                '''
            }
        }
    }
    post {
        always {
            // Ausgelesener Cleanup nach Beendigung
            sh 'pkill -f "python src/hello.py" || true'
        }
    }
}

```

---

## 5. Ergebnisse & Validierung

### 5.1 Eigener Unit-Test (Kriterium 6.2)

Zur vollständigen Erfüllung der Kriterien wurde in `tests/test_hello.py` ein eigener Test integriert, der die Integrität der JSON-Struktur validiert:

```python
def test_daniel_api_response():
    import sys
        import os
        sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
    
    from src.hello import app
    client = app.test_client()
    response = client.get('/api/hello')
    assert response.status_code == 200
    assert b"Hello Spencer" in response.data

```
Fehler von mir war das ich den Pfad falsch angegeben habe

### 5.2 Testlauf-Ergebnis

Die Pipeline lief fehlerfrei durch. Die Testsuite meldete ein erfolgreiches `OK` (inklusive des neuen Tests). Der abschließende API-Call via `curl` lieferte die korrekte Middleware-Antwort:

```json
{
  "counter": 31,
  "message": "Hello Spencer",
  "status": "success"
}

```

# TEIL 2: Theorie

### 1. Warum mussten wir Befehle im Terminal eingeben? (`docker run ...`)
Mein Mac nutzt ein anderes Betriebssystem (macOS) als die meisten Server (Linux). Damit Jenkins bei mir läuft, sperren ich es in einen Linux-Container ein. 
* Der Parameter `-v /var/run/docker.sock:/var/run/docker.sock` ist der Schlüssel: Damit erlaubt man dem Jenkins-Container, dem Docker-Programm auf meinem Mac Befehle zu erteilen. Jenkins kann dadurch eigenständig neue Container starten und stoppen.

### 2. Was war das Problem mit dem Fehler `Invalid agent type "docker"`?
Standardmäßig kann Jenkins nur einfache Skripte ausführen. Das Jenkinsfile von Prof. Micheler verlangt aber einen `agent { docker { ... } }`. Jenkins wusste schlicht nicht, was das Wort "docker" in diesem Zusammenhang bedeutet. Durch die Installation des **Docker Pipeline Plugins** habe ich Jenkins dieses neue Vokabular beigebracht.

### 3. Was genau passiert im Jenkinsfile?
Das Jenkinsfile liest sich von oben nach unten wie ein Kochrezept:
* **`agent { docker { image 'python:3.11' } }`**: Jenkins erstellt eine virtuelle Küche, in der bereits alles für Python 3.11 vorbereitet ist.
* **`Pre-Build Cleanup`**: Schaut nach, ob von einem alten Versuch noch die App läuft und blockiert. Wenn ja, wird sie rigoros beendet (`pkill`).
* **`Build`**: Lädt die benötigten Python-Pakete (`flask` für die API, `pytest` für die Tests) herunter.
* **`Test`**: Führt die Testdateien aus. Wenn hier ein Fehler im Code ist, bricht Jenkins sofort ab und markiert alles als ROT. Die App geht so niemals kaputt live.
* **`Run`**: Startet die App im Hintergrund (`nohup ... &`) und schickt einen Test-Abruf (`curl`) an die API, um zu sehen, ob sie antwortet.

### 4. Warum haben wir `Poll SCM` (`* * * * *`) genutzt?
Ein echtes GitHub würde Jenkins über einen "Webhook" anfunken, sobald du Code hochlädst. Da dein Mac aber im privaten WLAN/Schulnetzwerk hinter einer Firewall sitzt, kann GitHub deinen Mac nicht direkt erreichen. 
* **Die Lösung:** Mit `Poll SCM` drehen wir den Spieß um. Jenkins läuft Amok und fragt jede Minute bei GitHub nach: *"Gibt es was Neues? Gibt es was Neues?"*. Sobald du einen Commit machst, schlägt Jenkins beim nächsten Check zu und baut die Pipeline neu. Das erfüllt die Anforderung für den automatischen Start perfekt.


```